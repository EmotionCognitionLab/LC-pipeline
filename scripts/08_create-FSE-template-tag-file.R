# this script creates a tag file for FSE-template building on flywheel
# (it also saves a .csv record of scans used for template-building)
# written by shelby bachman, sbachman@usc.edu


# setup -------------------------------------------------------------------

rm(list = ls())
library(here)
library(reticulate)
library(stringr)
library(data.table)
library(dplyr)
library(lubridate)
library(jsonlite)
flywheel <- import('flywheel')


# parameters --------------------------------------------------------------

### name of group on flywheel
name_group <- 'emocog'

### name of project on flywheel
name_project <- 'PROJECT'

### shorthand version of project name, for saving local filenames
name_project_local <- 'PROJECTNAME'

### tag for FSE template-building
tag <- paste(name_project_local, 'mtc-FSE', today(), sep = '_')

### full path to csv containing FSE-MPR registrationsynquick job info
file_record_rsq <- list.files(here('records'), 
                              pattern = '*rsq-FSE-to-MPRAGE.csv', 
                              full.names = TRUE)


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# read csv containing input file info -------------------------------------

data_scans <- fread(file_record_rsq)


# create tag file for FSE template-building -------------------------------

list_files <- vector(mode = 'list', length = nrow(data_scans))
for (ii in 1:nrow(data_scans)) {
  list_files[[ii]]$parentId = data_scans$id_analysis_rsq[ii]
  list_files[[ii]]$sessId = data_scans$id_session[ii]
  list_files[[ii]]$name = data_scans$output_rsq[ii]
  list_files[[ii]]$parentType = 'analysis'
}

json_full <- NULL
json_full$tag <- tag
json_full$files <- list_files
write_json(json_full, 
           path = here('records', paste(today(), name_project_local, 'mtc-FSE.json', sep = '_')), 
           auto_unbox = TRUE)
rm(list_files, ii)


# prompt user to modify tag files before uploading ------------------------

# NOTE: at this step, you should open each file and add square brackets around the entire contents of each

check <- 0
while (check == 0) {
  print('Open the .json file you just created (located at: records/*mtc-FSE*.json)')
  print('Add square brackets (e.g. [ ]) around the entire contents of each file.')
  print('Finally, save each file.')
  answer <- readline(prompt = 'Have you done the above steps? (Enter y/n):')
  if (answer == 'y') {
    check <- 1
    break
  } else {
    check <- 0
  }
}


# upload tag files to flywheel --------------------------------------------

project$upload_file(here('records', paste(today(), name_project_local, 'mtc-FSE.json', sep = '_')))
