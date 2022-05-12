
library(dplyr)
library(lubridate)

# setwd("H:/eeg database/")
# setwd("/Users/ellisca/Box/")
setwd("X:/projects/EEG Database copy/")

rm(list = ls())

eegltm <- read.csv("EEGLTM.txt")

## look-up table for EEG site (1 = EEG lab)
site <- read.csv("EEG_Test_Site.txt", header = FALSE)

## filter to site = EEG lab
eeg_outpt <- eegltm[eegltm$Location == 1,]

## convert start and end times to datetime format
eeg_outpt$start <- as.POSIXct(eeg_outpt$Start.Time, format="%m/%d/%Y %H:%M:%S")
eeg_outpt$end <- as.POSIXct(eeg_outpt$End.Time, format="%m/%d/%Y %H:%M:%S")

## calculate EEG duration
eeg_outpt$duration <- difftime(eeg_outpt$end, eeg_outpt$start, units = "mins")

## create new variable: was EEG performed before or after 1/1/2020?
## TRUE = before 1/1/2020
## FALSE = after 1/1/2020
d <- as.POSIXct("2020-01-01")
eeg_outpt$pre_post <- difftime(eeg_outpt$date, d, units = "days") < 0

# create new variable: month and year (to get de-identified data)
eeg_outpt$month_year <- as.POSIXct(eeg_outpt$Start.Time, format="%m/%Y")

## limit data to duration < 120 minutes
eeg_outpt2 <- eeg_outpt[eeg_outpt$duration < 120,]

## histograms of EEG duration
#hist(as.numeric(eeg_outpt2$duration))

#hist(as.numeric(eeg_outpt2$duration[eeg_outpt2$pre_post == TRUE]))
#hist(as.numeric(eeg_outpt2$duration[eeg_outpt2$pre_post == FALSE]))
