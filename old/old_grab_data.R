
library(dplyr)
library(lubridate)
library(stringr)

# setwd("H:/eeg database/")
# setwd("/Users/ellisca/Box/")
setwd("C:/Users/conrade/Desktop/EEG Database copy")

rm(list = ls())

eegltm <- read.csv("EEGLTM2.txt")

## look-up table for EEG site (1 = EEG lab)
site <- read.csv("EEG_Test_Site.txt", header = FALSE)

## filter to site = EEG lab
eeg_outpt <- eegltm[eegltm$Location == 1,]

## convert start and end atimes to datetime format
eeg_outpt$start <- as.POSIXct(eeg_outpt$Start.Time, format="%m/%d/%Y %H:%M:%S")
eeg_outpt$end <- as.POSIXct(eeg_outpt$End.Time, format="%m/%d/%Y %H:%M:%S")

## calculate EEG duration
eeg_outpt$duration <- difftime(eeg_outpt$end, eeg_outpt$start, units = "mins")

## create new variable: was EEG performed before or after 1/1/2020?
## TRUE = before 1/1/2020
## FALSE = after 1/1/2020
d <- as.POSIXct("2020-01-01")
eeg_outpt$pre_post <- difftime(eeg_outpt$start, d, units = "days") < 0

## limit data to duration < 120 minutes
eeg_outpt2 <- eeg_outpt[eeg_outpt$duration < 120,]

# get de-identified start time
#eeg_outpt2$start_deid <- format(eeg_outpt2$start,format = "%m-%Y")
eeg_outpt2$start_deid <- floor_date(eeg_outpt2$start,'month')

# Make a new list with just the stuff I want
new <- list(start = eeg_outpt2$start_deid,duration = eeg_outpt2$duration)
new$location <- eeg_outpt2$Location
new$interpretation_findings <- eeg_outpt2$interpretation_findings
new$sleep <- eeg_outpt2$Sleep
new$pre_post <- eeg_outpt2$pre_post

# Find the hosital, regular expression
a <- str_locate_all(eeg_outpt2$EEG.number,"[ntNT]-")
new$hosp <- vector()
i <- 1
while (i < count(eeg_outpt2)+1) {
	str <- eeg_outpt2$EEG.number[i]
	new$hosp[length(new$hosp) + 1] <- substr(str,1,a[[i]][1])
	i <- i+1
}

# output list to a vsv
write.table(new,file = "out.csv",sep=",",row.names = FALSE, col.names = TRUE)

## histograms of EEG duration
#hist(as.numeric(eeg_outpt2$duration))

#hist(as.numeric(eeg_outpt2$duration[eeg_outpt2$pre_post == TRUE]))
#hist(as.numeric(eeg_outpt2$duration[eeg_outpt2$pre_post == FALSE]))
