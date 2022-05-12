function main_analyses

do_plots = 1;
close all

data_folder = '../../data/';
filename = 'deid_info.xlsx';
results_folder = '../../results/';

if ~exist(results_folder,'dir')
    mkdir(results_folder)
end

%% Load Table
opts = detectImportOptions([data_folder,filename]);
opts = setvartype(opts,'char');  % or 'string'
T = readtable([data_folder,filename],opts);


%% Restrict to Outpatient EEGs
outpatient = cellfun(@(x) contains(x,'out','ignorecase',true),T.hosp);
T(~outpatient,:) = [];

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

%% Pre or post 2020
pre_2020 = strcmp(T.pre_post,'true');
post_2020 = strcmp(T.pre_post,'false');
pre_or_post = cell(n_eegs,1);
pre_or_post(pre_2020) = {'Pre-2020'};
pre_or_post(post_2020) = {'Post-2020'};

%% duration
duration = cellfun(@str2num,T.duration);
short = duration < 40;
new_short = cell(n_eegs,1);
new_short(short == 1) = {'Short (<40 minutes)'};
new_short(short == 0) = {'Long (>=40 minutes)'};

%% HV
hv_not_done = cellfun(@(x) strcmp(x,'1') | strcmp(x,'NA'),T.HV);
hv_done = ~hv_not_done;
new_hv = cell(n_eegs,1);
new_hv(hv_done == 1) = {'HV performed'};
new_hv(hv_done == 0) = {'HV not performed'};

%% epileptiform discharges or seizures
discharges = [5 6 7];
slowing = [2 3 4];
seizures = [8 9];
abnormal = [discharges,slowing,seizures];
eegs_with_discharges = cellfun(@(x) text_contains_num(x,discharges), T.interpretation_findings);
new_discharges = cell(n_eegs,1);
new_discharges(eegs_with_discharges == 1) = {'Discharges present'};
new_discharges(eegs_with_discharges == 0) = {'Discharges absent'};


[counts,E,Y] = bin_counts_dates(hv_done,date_time,'month');


if do_plots
    
    
    %% Does presence of discharges differ by HV or not
    % No
    [tbl,chi2,p,labels] = crosstab(hv_done,new_discharges);
    figure
    pretty_table(tbl,labels,'Presence of discharges by HV',p)
    print(gcf,[results_folder,'discharges_by_HV'],'-dpng')
    
    
    %% Plot of presence of discharges as a function of time
    figure
    tiledlayout(2,1)
    nexttile
    plot(counts(:,1)./counts(:,2))
    xticks(1:size(counts,1))
    xticklabels(datestr(E(1:end-1)))
    title('Proportion of EEGs with discharges')
    
    nexttile
    plot(counts(:,2))
    xticks(1:size(counts,1))
    xticklabels(datestr(E(1:end-1)))
    title('Total number of EEGs')
    
    
    
    %{
    %% Does presence of discharges differ by duration - pre-2020
    [tbl,chi2,p,labels] = crosstab(new_short(pre_2020),new_discharges(pre_2020));
    figure
    pretty_table(tbl,labels,'Presence of discharges by duration (pre 2020)',p)
    %print(gcf,[results_folder,'discharges_by_hospital'],'-dpng')
    
    %% Does presence of discharges differ by duratiojn - post-2020
    [tbl,chi2,p,labels] = crosstab(new_short(post_2020),new_discharges(post_2020));
    figure
    pretty_table(tbl,labels,'Presence of discharges by duration (post 2020)',p)
    %}
    
    %% Histogram of durations pre- and post-2020
    figure
    histogram(duration(pre_2020));
    hold on
    histogram(duration(post_2020));
    legend({'Pre-2020','Post-2020'})
    xlabel('Duration (minutes)')
    ylabel('Number of EEGs')
    title('EEG duration by date')
    set(gca,'fontsize',20)
    print(gcf,[results_folder,'duration_by_date'],'-dpng')
    
    %% Does presence of discharges differ by pre vs post 2020?
    % Yes, higher pre-2020
    [tbl,chi2,p,labels] = crosstab(pre_or_post,new_discharges);
    figure
    pretty_table(tbl,labels,'Presence of discharges by date',p)
    print(gcf,[results_folder,'discharges_by_date'],'-dpng')
    
    %% Does presence of discharges differ by short vs long
    % NO
    [tbl,chi2,p,labels] = crosstab(new_short,new_discharges);
    figure
    pretty_table(tbl,labels,'Presence of discharges by EEG duration',p)
    print(gcf,[results_folder,'discharges_by_duration'],'-dpng')
    
    %% Do durations differ by hospital?
    % Yes
    [tbl,chi2,p,labels] = crosstab(hospital,new_short);
    figure
    pretty_table(tbl,labels,'EEG duration by site',p)
    print(gcf,[results_folder,'durations_by_hospital'],'-dpng')
    
    %% Does presence of discharges differ by hospital
    [tbl,chi2,p,labels] = crosstab(hospital,new_discharges);
    figure
    pretty_table(tbl,labels,'Presence of discharges by Hospital',p)
    print(gcf,[results_folder,'discharges_by_hospital'],'-dpng')
    
    %% Model predicting discharges according to hospital and  duration
    spikes = logical(eegs_with_discharges);
    new_tbl = table(spikes,hospital,new_short,pre_or_post);
    
    glm = fitglm(new_tbl,'spikes ~ hospital + new_short + pre_or_post','Distribution','binomial');

end

end

function out = text_contains_num(text,nums)

cnum = zeros(length(nums),1);

for in = 1:length(nums)
    cnum(in) = contains(text,sprintf('%d',nums(in)));
    
end

out = any(cnum);


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

function pretty_table(tbl,labels,title_text,p)
    imagesc(tbl)
    for ir = 1:size(tbl,1)
        for ic = 1:size(tbl,2)
            text(ic,ir,sprintf('%d (%1.1f%%)',tbl(ir,ic),tbl(ir,ic)/sum(tbl(ir,:))*100),...
                'horizontalalignment','center',...
                'fontsize',20)
        end
    end
    xticks(1:size(tbl,2))
    xticklabels(labels(:,2))
    yticks(1:size(tbl,1))
    yticklabels(labels(:,1))
    title(sprintf('%s p = %1.2e',title_text,p))
    set(gca,'fontsize',15)
end

function [counts,E,Y] = bin_counts_dates(thing,dates,bin_size)

%% Make bins
[Y,E] = discretize(dates,bin_size);
nbins = length(E)-1;

%% Get counts
counts = nan(nbins,2);
for ib = 1:nbins
    counts(ib,1) = sum(thing(Y==ib) == 1);
    counts(ib,2) = length(thing(Y==ib));
end



end