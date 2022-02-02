# this script gathers metadata for sessions within a flywheel project
# specifically, sessions with available MPRAGE & FSE scans
# written by shelby bachman, sbachman@usc.edu


# setup -------------------------------------------------------------------

rm(list = ls())
library(here)
library(reticulate)
library(stringr)
library(data.table)
library(dplyr)
library(lubridate)
flywheel <- import('flywheel')


# parameters --------------------------------------------------------------

### name of group on flywheel
name_group <- 'emocog'

### name of project on flywheel
name_project <- 'PROJECT' # example: '2018_Shelby_LC_fromGDA'

### shorthand version of project name, for saving local filenames
name_project_local <- 'PROJECTNAME' # example: 'GDA'

### acquisition labels on flywheel
label_FSE <- 'acq-FSE_T1w'
label_MPRAGE <- 'T1w'


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt = "Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# loop over sessions & extract metadata -----------------------------------

# NOTE: this finds all sessions with available MPRAGE and TSE scans

# list sessions in project
sessions <- project$sessions()
session_ids <- NULL
for (ii in 1:length(sessions)) {
  session_ids[ii] <- sessions[[ii]]$id
}
rm(ii)

label_session <- NULL
label_subject <- NULL
acq_id_FSE <- NULL
acq_id_MPRAGE <- NULL

for (ii in 1:length(sessions)) {
  
  # extract session & subject label for this session
  session <- fw$get(session_ids[ii])
  label_session[ii] <- session$label
  label_subject[ii] <- session$subject$label
  
  # get list of acquisitions for this session and loop over,
  # finding relevant MPRAGE and TSE IDs in each case
  acquisitions <- session$acquisitions()
  for (hh in 1:length(acquisitions)) {
    
    if (acquisitions[[hh]]$label == label_FSE) {
      acq_id_FSE[ii] <- acquisitions[[hh]]$id
      
    } else if (acquisitions[[hh]]$label == label_MPRAGE) {
      acq_id_MPRAGE[ii] <- acquisitions[[hh]]$id
    }
    
  }
  
}


# compile scan info as dataframe ------------------------------------------

data_sessions <- data.frame(label_subject, label_session, 
                            id_session = session_ids,
                            id_acq_FSE = acq_id_FSE,
                            id_acq_MPRAGE = acq_id_MPRAGE)


# check for and remove scans missing MPRAGE or FSE ------------------------

data_sessions <- data_sessions %>%
  filter(! is.na(id_acq_FSE) | is.na(id_acq_MPRAGE))

# NOTE: any other exclusions should be applied here


# create records subdirectory if necessary --------------------------------

if (!dir.exists(here('records'))) {
  dir.create(here('records'))
}


# save record -------------------------------------------------------------

write.csv(data_sessions, 
          here('records', paste(name_project_local, '_session-info.csv', sep = '')), 
          row.names = FALSE, quote = FALSE)
