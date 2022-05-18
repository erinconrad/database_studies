function general_tests

data_folder = '../data/';
filename = 'all_deid.xlsx';
results_folder = '../../results/';

%% Load Table
opts = detectImportOptions([data_folder,filename]);
opts = setvartype(opts,'char');  % or 'string'
T = readtable([data_folder,filename],opts);
neegs = size(T,1);

%% convert dates to datetime
date_str = T.start;
date_time = cellfun(@datetime,date_str);

%% Find inpatient/outpatient
outpatient = cellfun(@(x) contains(x,'out','ignorecase',true),T.hosp);
inpatient = cellfun(@(x) contains(x,'in','ignorecase',true),T.hosp);

%% epileptiform discharges or seizures
discharges = [5 6 7];
slowing = [2 3 4];
seizures = [8 9];
is_sz = cellfun(@(x) text_contains_num(x,seizures), T.interpretation_findings);

%% Number of EEGs every month
if 0
thing = ones(neegs,1);
[counts,E,Y] = bin_counts_dates(thing,date_time,'month');

figure
plot(counts,'linewidth',2)
xticks(1:size(counts,1))
xticklabels(datestr(E(1:end-1)))
title('Number of EEGs')
end

%% Number of inpatient EEGs every month
if 0
ninpatient = sum(inpatient);
thing = ones(ninpatient,1);
date_time_inpatient = date_time(inpatient);
[counts,E,Y] = bin_counts_dates(thing,date_time_inpatient,'month');

figure
plot(counts,'linewidth',2)
xticks(1:size(counts,1))
xticklabels(datestr(E(1:end-1)))
title('Number of Inpatient EEGs')
end

%% Number of inpatient EEGs with seizures every month
ninpatient = sum(inpatient);
thing = is_sz(inpatient);
date_time_inpatient = date_time(inpatient);
[counts,E,Y] = bin_counts_dates(thing,date_time_inpatient,'month');
figure
tiledlayout(2,1)
nexttile
plot(counts(:,1)./counts(:,2))
xticks(1:size(counts,1))
xticklabels(datestr(E(1:end-1)))
title('Proportion of inpatient EEGs with seizures')

nexttile
plot(counts(:,2))
xticks(1:size(counts,1))
xticklabels(datestr(E(1:end-1)))
title('Total number of inpatient EEGs')

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

