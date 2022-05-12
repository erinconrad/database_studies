function get_stats_on_ltm_sessions

data_folder = '../data/';
filename = 'eegs_deid.xlsx';
results_folder = '../../results/';

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
hospital = T.hosp;
n_eegs = size(T,1);

%% convert dates to datetime
date_str = T.start;
date_time = cellfun(@datetime,date_str);

%% duration
duration = cellfun(@(x) str2double(x),T.duration);

%% fake ids
fake_id = cellfun(@(x) str2double(x),T.fake_id);


%% Get sessions
session_id = str2double(T.session_id);
unique_sessions = unique(session_id);
nsessions = length(unique(session_id));

%% Get stats on sessions
neegs_per_session = nan(nsessions,1);
duration_per_session = nan(nsessions,1);
eegs_per_session = cell(nsessions,1);
for i = 1:nsessions
    curr_session = unique_sessions(i);
    
    % get eegs matching
    curr_eegs = session_id == curr_session;
    eegs_per_session{i} = find(curr_eegs);
    
    neegs_per_session(i) = sum(curr_eegs);
    
    % confirm that patient ids all the same
    assert(length(unique(fake_id(curr_eegs)))==1)
    
    % Get the associated durations
    curr_durations = duration(curr_eegs);
    
    % sum up the full duration
    duration_per_session(i) = sum(curr_durations);
end

% look for funny sessions
[~,longest_session] = max(duration_per_session);

% find ltms
is_ltm = duration_per_session > 60*12;
fprintf('\nOf the %d session, %d are longer than 12 hours.\n',...
    nsessions,sum(is_ltm));
figure
nexttile
histogram(duration_per_session(is_ltm)/60/24)
xlabel('Days')
ylabel('Number of LTM sessions')
title('Total duration of LTM sessions')
set(gca,'fontsize',15)

nexttile
histogram(neegs_per_session(is_ltm))
xlabel('Number of EEGs per LTM session')
ylabel('Number of LTM sessions')
title('Number of EEGs per LTM session')
set(gca,'fontsize',15)

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