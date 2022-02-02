# this script downloads FSE & MPRAGE templates warped to MNI space
# from flywheel
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
name_project <- 'PROJECT'

### shorthand version of project name, for saving local filenames
name_project_local <- 'PROJECTNAME'

# name of registrationSyN analysis on flywheel containing MPR template in MNI space
analysis_rs_MPR_to_MNI <- 'ANALYSIS_NAME'

# name of registrationSyN analysis on flywheel containing FSE template in MPRAGE template space
analysis_rs_FSE_to_MPR <- 'ANALYSIS_NAME'

# name of apply-transforms analysis on flywheel containing FSE template in MNI space
analysis_aat_FSE_to_MNI <- 'ANALYSIS_NAME'
  

# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# find & download MPRAGE template in MNI space ----------------------------

name_template <- paste(name_project_local, 'MPR-to-MNI_Warped.nii.gz', sep = '_')

# find analysis
for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_rs_MPR_to_MNI) {
    analysis <- project$analyses[[ii]]
  }
}
rm(ii)

# find template file
for (ii in 1:length(analysis$files)) {
  if (analysis$files[[ii]]$name == name_template) {
    template_mprage <- analysis$files[[ii]]
  } 
}
rm(analysis, ii)

# download template file
fname_download <- paste(name_project_local, 'template-MPR_warped-MNI.nii.gz', sep = '_')
path_download <- here('templates', fname_download)
template_mprage$download(path_download)
message(paste('downloaded: ', template_mprage$name, sep = ''))


# find & download FSE template in MPRAGE template space -------------------

name_template <- paste(name_project_local, 'FSE-to-MPR_Warped.nii.gz', sep = '_')

# find analysis
for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_rs_FSE_to_MPR) {
    analysis <- project$analyses[[ii]]
  }
}
rm(ii)

# find template file
for (ii in 1:length(analysis$files)) {
  if (analysis$files[[ii]]$name == name_template) {
    template_FSE <- analysis$files[[ii]]
  } 
}
rm(analysis, ii)

# download template file
fname_download <- paste(name_project_local, 'template-FSE_warped-MPR.nii.gz', sep = '_')
path_download <- here('templates', fname_download)
template_FSE$download(path_download)
message(paste('downloaded: ', template_FSE$name, sep = ''))
rm(template_FSE)


# find & download FSE template in MNI space -------------------------------

name_template <- 'mtc_template0_warped.nii.gz'

# find analysis
for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_aat_FSE_to_MNI) {
    analysis <- project$analyses[[ii]]
  }
}
rm(ii)

# find template file
for (ii in 1:length(analysis$files)) {
  if (analysis$files[[ii]]$name == name_template) {
    template_FSE <- analysis$files[[ii]]
  } 
}
rm(analysis, ii)

# download template file
fname_download <- paste(name_project_local, 'template-FSE_warped-MNI.nii.gz', sep = '_')
path_download <- here('templates', fname_download)
template_FSE$download(path_download)
message(paste('downloaded: ', template_FSE$name, sep = ''))
