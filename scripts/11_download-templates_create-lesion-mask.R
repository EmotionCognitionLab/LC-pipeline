# this script downloads MPRAGE & FSE templates from flywheel
# and creates a lesion mask of the FSE template
# (a binarized mask of the template)
# for coregistration of the FSE template to MPR template space
# written by shelby bachman, sbachman@usc.edu


# setup -------------------------------------------------------------------

rm(list = ls())
library(here)
library(reticulate)
library(ANTsRCore)
flywheel <- import('flywheel')


# parameters --------------------------------------------------------------

### name of group on flywheel
name_group <- 'emocog'

### name of project on flywheel
name_project <- 'PROJECT'

### shorthand version of project name, for saving local filenames
name_project_local <- 'PROJECTNAME'

### name of analysis on flywheel containing full MPRAGE template
analysis_mtc_mprage <- 'ANALYSIS_NAME'

### name of analysis on flywheel containing full FSE template
analysis_mtc_fse <- 'ANALYSIS_NAME'


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# create directory to download templates ----------------------------------

if (!dir.exists(here('templates'))) {
  dir.create(here('templates'))
}


# find & download MPRAGE template -----------------------------------------

name_template <- 'mtc_template0.nii.gz'

# find analysis
for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_mtc_mprage) {
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
fname_download <- paste(name_project_local, 'template-MPR.nii.gz', sep = '_')
path_download <- here('templates', fname_download)
template_mprage$download(path_download)
message(paste('downloaded: ', template_mprage$name, sep = ''))
rm(fname_download, path_download, template_mprage)


# find & download FSE template --------------------------------------------

name_template <- 'mtc_template0.nii.gz'

# find analysis
for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_mtc_fse) {
    analysis <- project$analyses[[ii]]
  }
}
rm(ii)

# find template file
for (ii in 1:length(analysis$files)) {
  if (analysis$files[[ii]]$name == name_template) {
    template_fse <- analysis$files[[ii]]
  } 
}
rm(analysis, ii)

# download template file
fname_download <- paste(name_project_local, 'template-FSE.nii.gz', sep = '_')
path_download <- here('templates', fname_download)
template_fse$download(path_download)
message(paste('downloaded: ', template_fse$name, sep = ''))
rm(fname_download, template_fse)


# create lesion mask of FSE template --------------------------------------

img <- antsImageRead(path_download)
img_bin <- thresholdImage(img, 1, Inf)
path_lesionmask <- here('templates',
                        paste(name_project_local, 'template-FSE_mask.nii.gz', sep = '_'))
antsImageWrite(img_bin, path_lesionmask)
rm(path_download)


# upload lesion mask to flywheel ------------------------------------------

project$upload_file(path_lesionmask)
message(paste('uploaded: ', path_lesionmask, sep = ''))
