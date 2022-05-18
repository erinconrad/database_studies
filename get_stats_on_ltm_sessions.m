function get_stats_on_ltm_sessions

%% Params
gap = 3600*24*3;

data_folder = '../data/';
filename = 'deid_eegs.xlsx';
results_folder = '../../results/';
addpath(genpath('.'))

if ~exist(results_folder,'dir')
    mkdir(results_folder)
end

%% Load Table
opts = detectImportOptions([data_folder,filename]);
opts = setvartype(opts,'char');  % or 'string'
T = readtable([data_folder,filename],opts);

%% Restrict to inpatient EEGs
inpatient = cellfun(@(x) contains(x,'in','ignorecase',true),T.hosp);
T(~inpatient,:) = [];

%% hospital
hospital = T.hosp;
new_hospital = rebin_hospital(hospital);
T.hosp = new_hospital;

%% Remove empty hospitals
empty_hospital = cellfun(@isempty,new_hospital);
T(empty_hospital,:) = [];

%% fake ids
fake_id = cellfun(@(x) str2double(x),T.fake_id);
% remove empty fake ids
T(fake_id==0,:) = [];
fake_id = cellfun(@(x) str2double(x),T.fake_id);

hospital = T.hosp;
n_eegs = size(T,1);

%% convert dates to datetime
% seconds since Jan 1 1970
start_date = cellfun(@(x) str2double(x),T.start); 
end_date = cellfun(@(x) str2double(x),T.xEnd);

%% duration
duration = cellfun(@(x) str2double(x),T.duration);
alt_duration = end_date-start_date; % figure out why some alt_durations are zero...
assert(isequal(duration(~isnan(duration)),alt_duration(~isnan(duration))))

[session_id,pt] = build_sessions(fake_id,start_date,end_date,gap,T);

%% Make a table of all sessions
%{
session_tab = [];
for ip = 1:length(pt)
    for is = 1:length(pt(ip).session)
        neegs = length(pt(ip).session(is).eegs);
        
        
        session_tab = [session_tab;...
            repmat(pt(ip).id,neegs,1),...
            repmat(pt(ip).session(is).id,neegs,1)...
            pt(ip).session(is).eegs,...
            pt(ip).session(is).times,...
            pt(ip).session(is).durations,...
            repmat(pt(ip).session(is).full_duration,neegs,1)...
            repmat(pt(ip).session(is).is_ltm,neegs,1),...
            repmat(pt(ip).session(is).routine_start,neegs,1)];
    end
    
end

sT = array2table(session_tab,'VariableNames',{'Patient','Session',...
    'EEG','Start','End','Duration','SessionDuration','LTM','RoutineStart'});

%% Sanity checks
empty_time = isnan(sT.Start) | isnan(sT.End);
assert(isequal(sT.End(~empty_time)-sT.Start(~empty_time),sT.Duration(~empty_time)))
%}

%% Make a table of LTM session info
session_tab = [];
for ip = 1:length(pt)
    for is = 1:length(pt(ip).session)
        neegs = length(pt(ip).session(is).eegs);
        session_tab = [session_tab;...
            pt(ip).id,...
            pt(ip).session(is).id,...
            neegs,...
            pt(ip).session(is).full_duration,...
            pt(ip).session(is).is_ltm,...
            pt(ip).session(is).routine_start,...
            pt(ip).session(is).start_duration,...
            pt(ip).session(is).any_sz,...
            pt(ip).session(is).first_sz,...
            pt(ip).session(is).first_spike];
        
    end
end
sT = array2table(session_tab,'VariableNames',{'Patient','Session',...
    'NumberEEGs','Duration','LTM','RoutineStart','StartDuration',...
    'AnySz','FirstSz','FirstSpike'});

%% Sanity checks
% sz stuff
no_sz = isnan(sT.FirstSz);
assert(~any(sT.AnySz(no_sz)==1));

%% Remove those with empty duration
empty_duration = isnan(sT.Duration);
sT(empty_duration,:) = [];

%% Restrict to LTM
ltm = sT.LTM;
sT(~ltm,:) = [];
assert(~any(sT.Duration<3600*12))

%% How many start with routines?
fprintf(['\n%d of %d LTM sessions start with routines.\n'],sum(sT.RoutineStart==1),...
    length(sT.RoutineStart));

%% Start duration
figure
histogram(sT.StartDuration/3600)
xlabel('Duration of first EEG (hours)')
ylabel('Number of sessions')
set(gca,'fontsize',15)

%% How many have seizures
fprintf(['\n%d of %d (%1.1f%%) of LTM sessions have seizures. '...
    'Of those with seizures, %d (%1.1f%%) occur in first report. \n'],sum(sT.AnySz==1),...
    length(sT.AnySz),sum(sT.AnySz==1)/length(sT.AnySz)*100,...
    sum(sT.FirstSz==1),sum(sT.FirstSz==1)/sum(sT.AnySz==1)*100);

%% Main spikey question
% Of patients who start with a routine, odds of sz if no spikes and no sz
% on routine?
nT = sT;
nT(sT.RoutineStart==0,:) = [];
pred = zeros(size(nT,1),1);
pred(nT.FirstSz==1 | nT.FirstSpike == 1) = 1;
pred = logical(pred);
predicted = cell(size(nT,1),1);
predicted(pred) = {'sz'};
predicted(~pred) = {'no_sz'};
actual = cell(size(nT,1),1);
actual(nT.AnySz == 1) = {'sz'};
actual(nT.AnySz ~= 1) = {'no_sz'};
out = jay_confusion_matrix(predicted,actual,1);

spike_mat = [sum(nT.AnySz == 1 & (nT.FirstSz==1 | nT.FirstSpike == 1)),... % yes sz and either spikes or sz on first eeg
    sum(nT.AnySz == 1 & ((nT.FirstSz>1 | isnan(nT.FirstSz)) & (nT.FirstSpike>1 | isnan(nT.FirstSpike))));... % yes sz and no spikes and no sz on first eeg
    sum(nT.AnySz == 0 & (nT.FirstSz==1 | nT.FirstSpike == 1)),... % no sz...
    sum(nT.AnySz == 0 & ((nT.FirstSz>1 | isnan(nT.FirstSz)) & (nT.FirstSpike>1 | isnan(nT.FirstSpike))))]; % no sz,...

end

function new_hospital = rebin_hospital(hospital)

hosps = {'HUP','PAH','PMC','RAD'};
new_hospital = cell(length(hospital),1);
for ih = 1:length(hospital)
    curr = hospital{ih};
    for iposs = 1:length(hosps)
        if contains(curr,hosps{iposs},'ignorecase',true)
            new_hospital{ih} = hosps{iposs};
            break
        end
    end
    
end

end

function y = str2num_with_nan(x)

if strcmp(x,'NA')
    y = nan;
else
    y = str2double(x);
end

end