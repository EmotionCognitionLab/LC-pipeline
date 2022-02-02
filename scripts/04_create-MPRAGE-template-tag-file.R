# this script creates tag files for MPRAGE-template building on flywheel
# (it also saves a .csv record of scans used for template-building)
# written by shelby bachman, sbachman@usc.edu


# setup -------------------------------------------------------------------

rm(list = ls())
library(here)
library(data.table)
library(dplyr)
library(stringr)
library(tidyr)
library(knitr)
library(lubridate)
library(reticulate)
library(jsonlite)
flywheel <- import('flywheel')


# parameters --------------------------------------------------------------

### name of group on flywheel
name_group <- 'emocog'

### name of project on flywheel
name_project <- 'PROJECT'

### shorthand version of project name, for saving local filenames
name_project_local <- 'PROJECTNAME'

### acquisition labels on flywheel
label_FSE <- 'acq-FSE_T1w'
label_MPRAGE <- 'T1w'

### tag for MPRAGE template-building
tag <- paste(name_project_local, 'mtc-MPRAGE', today(), sep = '_')

### full path to .csv record of scan resampling
file_record_resample <- list.files(here('records'), 
                                   pattern = '*resample-scans.csv', 
                                   full.names = TRUE)[1]

### full path to MPRAGE header data file
file_record_MPRhdr <- list.files(here('records'),
                                 pattern = '*MPRAGE-header-data.csv',
                                 full.names = TRUE)[1]

### for initial MPRAGE template, only include scans 
### with qoffset_x, qoffset_y, and qoffset_z values within X SD of the mean
thresh_SD <- 1


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# load scan data ----------------------------------------------------------

data_MPR <- fread(file_record_resample) %>%
  filter(label_acq == 'T1w') %>%
  rename(output_resampleImage_MPR = output_resampleImage, 
         label_acq_MPR = label_acq, 
         id_acq_MPR = id_acq, 
         id_job_resampleImage_MPR = id_job_resampleImage)

data_FSE <- fread(file_record_resample) %>%
  filter(label_acq == 'acq-FSE_T1w') %>%
  rename(output_resampleImage_FSE = output_resampleImage,
         label_acq_FSE = label_acq, 
         id_acq_FSE = id_acq,
         id_job_resampleImage_FSE = id_job_resampleImage)


# load MPRAGE header data -------------------------------------------------

data_MPRAGE_hdr <- fread(file_record_MPRhdr) %>%
  select(-filename)

# join header data with scan data
data_MPR <- data_MPR %>%
  left_join(data_MPRAGE_hdr, by = c('label_subject', 'label_session'))


# re-join FSE and MPR scan data -------------------------------------------

data_scans <- left_join(data_MPR, data_FSE, 
                  by = c('label_subject', 'label_session', 'id_session'))


# save csv of scans included for full template-building -------------------

write.csv(data_scans, 
          here('records', paste(today(), name_project_local, 'scans-for-template_mprage.csv', sep = '_')), 
          quote = FALSE, row.names = FALSE)


# identify MPRAGE scans for initial template-building ---------------------

data_scans_init <- data_scans 

# calculate means and SDs of qoffset_x, qoffset_y and qoffset_z
mean_qoffset_x <- mean(data_scans_init$qoffset_x)
mean_qoffset_y <- mean(data_scans_init$qoffset_y)
mean_qoffset_z <- mean(data_scans_init$qoffset_z)
sd_qoffset_x <- sd(data_scans_init$qoffset_x)
sd_qoffset_y <- sd(data_scans_init$qoffset_y)
sd_qoffset_z <- sd(data_scans_init$qoffset_z)

# include only scans with qoffset x/y/z each within X SD of the mean
data_scans_init <- data_scans_init %>%
  filter(qoffset_x <= (mean_qoffset_x + thresh_SD*sd_qoffset_x) & qoffset_x >= (mean_qoffset_x - thresh_SD*sd_qoffset_x)) %>%
  filter(qoffset_y <= (mean_qoffset_y + thresh_SD*sd_qoffset_y) & qoffset_y >= (mean_qoffset_y - thresh_SD*sd_qoffset_y)) %>%
  filter(qoffset_z <= (mean_qoffset_z + thresh_SD*sd_qoffset_z) & qoffset_z >= (mean_qoffset_z - thresh_SD*sd_qoffset_z))


# save csv of MPRAGE scans included for initial template ------------------

write.csv(data_scans_init, 
          here('records', paste(today(), name_project_local, 'scans-for-template_mprage-init.csv', sep = '_')),
          quote = FALSE, row.names = FALSE)


# create tag file for MPRAGE initial template-building --------------------

list_files <- vector(mode = 'list', length = nrow(data_scans_init))
for (ii in 1:nrow(data_scans_init)) {
  list_files[[ii]]$parentId = data_scans_init$id_acq_MPR[ii]
  list_files[[ii]]$sessId = data_scans_init$id_session[ii]
  list_files[[ii]]$name = data_scans_init$output_resampleImage_MPR[ii]
  list_files[[ii]]$parentType = 'acquisition'
}

json_init <- NULL
json_init$tag <- tag
json_init$files <- list_files
write_json(json_init, 
           path = here('records', paste(today(), name_project_local, 'mtc-MPRAGE_init.json', sep = '_')), 
           auto_unbox = TRUE)
rm(list_files, ii)


# create tag file for MPRAGE full template-building -----------------------

list_files <- vector(mode = 'list', length = nrow(data_scans))
for (ii in 1:nrow(data_scans)) {
  list_files[[ii]]$parentId = data_scans$id_acq_MPR[ii]
  list_files[[ii]]$sessId = data_scans$id_session[ii]
  list_files[[ii]]$name = data_scans$output_resampleImage_MPR[ii]
  list_files[[ii]]$parentType = 'acquisition'
}

json_full <- NULL
json_full$tag <- tag
json_full$files <- list_files
write_json(json_full, 
           path = here('records', paste(today(), name_project_local, 'mtc-MPRAGE.json', sep = '_')), 
           auto_unbox = TRUE)
rm(list_files, ii)


# prompt user to modify tag files before uploading ------------------------

# NOTE: at this step, you should open each file and add square brackets around the entire contents of each

check <- 0
while (check == 0) {
  print('Open the 2 .json files you just created (located at: records/*mtc-MPRAGE*.json)')
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

project$upload_file(here('records', paste(today(), name_project_local, 'mtc-MPRAGE_init.json', sep = '_')))
project$upload_file(here('records', paste(today(), name_project_local, 'mtc-MPRAGE.json', sep = '_')))
