
library(dplyr)
library(lubridate)
library(stringr)

# setwd("H:/eeg database/")
# setwd("/Users/ellisca/Box/")
setwd("C:/Users/conrade/Desktop/EEG Database copy")

rm(list = ls())

eegltm <- read.csv("EEGLTM2.txt")


# Build patient look up table
unique_pts <- unique(eegltm$Patient.ID)
npts <- length(unique_pts)
fake <- 1:npts
real <- unique_pts
pt_look <- list(fake=fake,real=real)
write.table(pt_look,file = "pt_lookup_table.csv",sep=",",row.names = FALSE, col.names = TRUE)

# Make new column for each eeg with fake id
neegs <- count(eegltm)
eegltm$fake_id <- vector("numeric",neegs)
i<-1
while (i < neegs+1){
	pt_id <- eegltm$Patient.ID[i]

	if (is.na(pt_id)){
		i <- i+1
		next
	}
	
	# find matching rows of lookup
	match <- which(real==pt_id)
	curr_fake <- fake[match] # get corresponding fake id
	eegltm$fake_id[i] <- curr_fake
	i <- i+1
}

## look-up table for EEG site (1 = EEG lab)
site <- read.csv("EEG_Test_Site.txt", header = FALSE)


## convert start and end atimes to datetime format
eegltm$start <- as.POSIXct(eegltm$Start.Time, format="%m/%d/%Y %H:%M:%S")
eegltm$end <- as.POSIXct(eegltm$End.Time, format="%m/%d/%Y %H:%M:%S")

## calculate EEG duration
eegltm$duration <- difftime(eegltm$end, eegltm$start, units = "mins")

## create new variable: was EEG performed before or after 1/1/2020?
## TRUE = before 1/1/2020
## FALSE = after 1/1/2020
d <- as.POSIXct("2020-01-01")
eegltm$pre_post <- difftime(eegltm$start, d, units = "days") < 0

# get de-identified start time
eegltm$start_deid <- floor_date(eegltm$start,'month')

# Make a new list with just the stuff I want
new <- list(start = eegltm$start_deid,duration = eegltm$duration)
new$location <- eegltm$Location
new$interpretation_findings <- eegltm$interpretation_findings
new$sleep <- eegltm$Sleep
new$pre_post <- eegltm$pre_post
new$HV <- eegltm$HV
new$PS <- eegltm$PS
new$fake_id <- eegltm$fake_id

# Loop over all EEGs, grab patient, find EEGs with same patient, add to session if close
neegs <- length(new$HV) # get number of eegs
new$session_id <- vector("numeric",neegs) # initialize vector of session ids
i <- 1 # initialize which eeg
curr_session <- 0 # initialize which eeg session
while (i < count(eegltm) +1) { # Loop over EEGs
	
	
	if (new$session_id[i] != 0){
		i<-i+1
		next # skip if already have session
	}

	# skip if patient ID is NA
	if (is.na(eegltm$Patient.ID[i])){
		curr_session <- curr_session + 1
		new$session_id[i] <- curr_session
		i<-i+1
		next
	}

	curr_session <- curr_session + 1 # increase session index if made it here
	new$session_id[i] <- curr_session # this will be the session for this eeg
	
	curr_pt <- eegltm$Patient.ID[i] # get current pt
	same_pt_eegs <- which(eegltm$Patient.ID==curr_pt & eegltm$start >= eegltm$start[i]) # find indices of eegs with same patient occuring after current
	same_pt_sort <- order(eegltm$start[same_pt_eegs])
	sorted_indices <- same_pt_eegs[same_pt_sort]

	stopifnot(sorted_indices[1] == i) # be sure that the first in this sorted list is the current eeg
	
	# Loop over sorted eegs
	j <- 2 # start with one after current one
	while (j < length(sorted_indices)+1){
		# see if the date is within 2 days of last one
		if (difftime(eegltm$start[sorted_indices[j]], eegltm$start[sorted_indices[j-1]], units = "days") <= 2) {
			new$session_id[sorted_indices[j]] <- curr_session # make these the same session
		} else {
			break
		}
		j <- j + 1
	}

	i<- i + 1 # go to next eeg
}

# Do some tests of this process
unique_sessions <- unique(new$session_id)
nunique = length(unique_sessions)
i<-1
# loop over unique sessions
while (i<nunique+1){
	# Get the eegs with that session id
	curr_session <- unique_sessions[i]
	same_session_eegs <- which(new$session_id==curr_session)

	# confirm that these eegs all have the same patient id
	same_session_pts <- eegltm$Patient.ID[same_session_eegs]
	stopifnot(length(unique(same_session_pts))==1)
	

	i <- i+1
}

# Get the durations of each session
session_duration <- vector("numeric",nunique) # initialize vector with duration of each session
i<-1
while (i<nunique+1){ # loop over unique sessions
	# Get the eegs with that session id
	curr_session <- unique_sessions[i]
	same_session_eegs <- which(new$session_id==curr_session)

	# Get the start times and end times
	curr_session_start = eegltm$start[same_session_eegs]
	curr_session_end = eegltm$end[same_session_eegs]

	# get the min and max
	max_end = max(curr_session_end)
	min_start = min(curr_session_start)

	# get the difference between them to get full duration
	full_dur <- difftime(max_end,min_start,units="hours")
	session_duration[i] <- full_dur

	i <- i+1
	
}

# Find the hosital, regular expression
a <- str_locate_all(eegltm$EEG.number,"[ntNT]-")
new$hosp <- vector()
i <- 1
while (i < count(eegltm)+1) {
	str <- eegltm$EEG.number[i]
	new$hosp[length(new$hosp) + 1] <- substr(str,1,a[[i]][1])
	i <- i+1
}



# output list to a vsv
write.table(new,file = "deid_eegs.csv",sep=",",row.names = FALSE, col.names = TRUE)
