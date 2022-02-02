# this script runs the antsapplytransforms gear on flywheel
# to warp resampled FSE scans to MNI space
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

### name of MNI152 brain file on Flywheel 
# this should already be uploaded to Information --> Attachments on Flywheel
mni_name <- 'MNI_filename.nii.gz' # example: 'avg152T1_brain.nii.gz'

### name of registrationSyN analysis on flywheel containing FSE-MPR transforms
analysis_rs_FSE_to_MPR <- 'ANALYSIS_NAME'

### name of registrationSyN analysis on flywheel containing MPR-MNI transforms
analysis_rs_MPR_to_MNI <- 'ANALYSIS_NAME'

### name of full FSE template-building analysis on flywheel
analysis_FSE_template <- 'ANALYSIS_NAME'

### name of .zip file within full FSE template-creating analysis output on flywheel
name_zipfile <- 'filename.zip'

### full path to local .csv record of rsq FSE-to-MPRAGE analyses
list_file <- list.files(here('records'), 
                        pattern = '*rsq-FSE-to-MPRAGE.csv', 
                        full.names = TRUE)

### acquisition labels on flywheel
label_FSE <- 'acq-FSE_T1w'

### analysis label
analysis_label <- paste(name_project_local, 'aat-FSE-to-MNI', today(), sep = '_')


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# find reference (MNI) image on flywheel ----------------------------------

for (ii in 1:length(project$files)) {
  if (project$files[[ii]]$name == mni_name) {
    input_ref <- project$files[[ii]]
  }
}
rm(ii)


# find transformations from FSE -> MPRAGE registration --------------------

which_file_lin <- paste(name_project_local, 'FSE-to-MPR_0GenericAffine.mat', sep = '_')
which_file_nlin <- paste(name_project_local, 'FSE-to-MPR_1Warp.nii.gz', sep = '_')

for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_rs_FSE_to_MPR) {
    t_analysis <- project$analyses[[ii]]
  }
}
rm(ii)

for (ii in 1:length(t_analysis$files)) {
  if (t_analysis$files[[ii]]$name == which_file_lin) {
    FSE_to_MPRAGE_affine <- t_analysis$files[[ii]]
  } else if (t_analysis$files[[ii]]$name == which_file_nlin) {
    FSE_to_MPRAGE_nonlin <- t_analysis$files[[ii]]
  }
}
rm(analysis_rs_FSE_to_MPR, which_file_lin, which_file_nlin, t_analysis, ii)


# find transformations from MPRAGE -> MNI registration --------------------

which_file_lin <- paste(name_project_local, 'MPR-to-MNI_0GenericAffine.mat', sep = '_')
which_file_nlin <- paste(name_project_local, 'MPR-to-MNI_1Warp.nii.gz', sep = '_')

for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_rs_MPR_to_MNI) {
    t_analysis <- project$analyses[[ii]]
  }
}
rm(ii)

for (ii in 1:length(t_analysis$files)) {
  if (t_analysis$files[[ii]]$name == which_file_lin) {
    MPRAGE_to_MNI_affine <- t_analysis$files[[ii]]
  } else if (t_analysis$files[[ii]]$name == which_file_nlin) {
    MPRAGE_to_MNI_nonlin <- t_analysis$files[[ii]]
  }
}
rm(analysis_rs_MPR_to_MNI, which_file_lin, which_file_nlin, ii)


# find zip file from FSE template building step ---------------------------

# find analysis from FSE template building
for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_FSE_template) {
    analysis <- project$analyses[[ii]]
  }
}
rm(analysis_FSE_template, ii)

# find zip file and template file
name_FSEtemplate <- 'mtc_template0.nii.gz'

for (ii in 1:length(analysis$files)) {
 if (analysis$files[[ii]]$name == name_zipfile) {
   zipfile <- analysis$files[[ii]]
 } else if (analysis$files[[ii]]$name == name_FSEtemplate) {
   FSEtemplate <- analysis$files[[ii]]
 }
}
rm(name_zipfile, name_FSEtemplate, ii)

# get zip file info
zipInfo <- zipfile$get_zip_info()


# read .csv containing RSQ analysis info ----------------------------------

list_table <- fread(list_file)


# create table with zip member info ---------------------------------------

files_num <- NULL
files_name <- NULL
files_type <- NULL
files_size <- NULL

for (ii in 1:length(zipInfo$members)) {
  files_num[ii] <- ii
  files_name[ii] <- zipInfo$members[[ii]]$path
  name_split <- str_split(zipInfo$members[[ii]]$path, '_Warped')
  suffix <- str_remove_all(name_split[[1]][2], '[[:digit:]]')
  suffix_stripped <- str_split(suffix, '.nii.gz')[[1]][1]
  files_type[ii] <- suffix_stripped
  files_size[ii] <- zipInfo$members[[ii]]$size/1e6
}
rm(ii)

# filter to include only nonlinear & affine transformations
files_table <- data.frame(files_num, files_name, files_type, files_size)
files_table_main <- files_table %>%
  filter(files_type == 'Warp' | files_type == 'Affine.txt')

# add labels for subject and session
files_table_main <- files_table_main %>%
  rowwise() %>%
  mutate(label_session = str_split(files_name, '_')[[1]][3],
         temp = str_split(files_name, '_')[[1]][2],
         subject = str_split(temp, '-sub-')[[1]][2]) %>%
  mutate(label_subject = str_c('sub-', subject, sep = '')) %>%
  select(-temp)


# set gear info -----------------------------------------------------------

gear <- fw$lookup('gears/ants-applytransforms')


# loop over RSQ outputs, identify inputs & run gear -----------------------

label_subject_record <- NULL
label_session_record <- NULL
id_subject_record <- NULL
id_session_record <- NULL
rsq_analysis_id <- NULL
mtcFSE_analysis_id <- NULL
aat_analysis_id <- NULL

for (ii in 1:nrow(list_table)) {
  
  ### which subject and session?
  this_sub <- list_table$label_subject[ii]
  this_ses <- list_table$label_session[ii]
  label_subject_record[ii] <- this_sub
  label_session_record[ii] <- this_ses
  
  ### which RSQ analysis and session?
  id_RSQanalysis <- list_table$id_analysis_rsq[ii]
  rsq_analysis_id[ii] <- id_RSQanalysis
  this_RSQanalysis <- fw$get(id_RSQanalysis)
  
  id_session <- list_table$id_session[ii]
  id_session_record[ii] <- id_session
  
  mtcFSE_analysis_id <- analysis$id
  
  ### identify inputs within rsq analysis
  for (hh in 1:length(this_RSQanalysis$files)) {
    if (this_RSQanalysis$files[[hh]]$type == 'nifti' | (this_RSQanalysis$files[[hh]]$type == 'MATLAB data')) {
      temp <- str_split(this_RSQanalysis$files[[hh]]$name, '_')
      if (temp[[1]][length(temp[[1]])] == '1Warp.nii.gz') {
        transform_3_filename <- this_RSQanalysis$files[[hh]]$name
        input_RSQnonlin <- this_RSQanalysis$files[[hh]]
      } else if (temp[[1]][length(temp[[1]])] == '0GenericAffine.mat') {
        transform_4_filename <- this_RSQanalysis$files[[hh]]$name
        input_RSQaffine <- this_RSQanalysis$files[[hh]]
      }
    }
  }
  rm(hh)
  
  ### identify corresponding BTP outputs
  this_subset <- files_table_main %>%
    filter(label_subject == this_sub & label_session == this_ses)
  transform_5_filename <- as.character(this_subset$files_name[this_subset$files_type == 'Warp'])
  transform_6_filename <- as.character(this_subset$files_name[this_subset$files_type == 'Affine.txt'])

  ### identify corresponding FSE acquisition
  this_session <- fw$get(id_session)
  expected_acq_name <- paste(this_sub, this_ses, paste(label_FSE, '_resamp.nii.gz', sep = ''), sep = '_')
  
  for (acquisition in iterate(this_session$acquisitions$iter_find('files.type=nifti'))){
    if (acquisition$label == label_FSE ) {
      this_acq <- acquisition
    }
  }
  
  for (hh in 1:length(this_acq$files)) {
    if (this_acq$files[[hh]]$name == expected_acq_name) {
      input_in <- this_acq$files[[hh]]
    }
  }
  rm(hh)
  
  ### set inputs
  inputs = dict('input_file'=input_in, 
                'reference_file'=input_ref,
                'transform_file_1'=MPRAGE_to_MNI_nonlin,
                'transform_file_2'=MPRAGE_to_MNI_affine,
                'transform_file_3'=FSE_to_MPRAGE_nonlin,
                'transform_file_4'=FSE_to_MPRAGE_affine,
                'transform_file_5'=zipfile,
                'transform_file_7'=input_RSQnonlin,
                'transform_file_8'=input_RSQaffine)

  ### set config
  config <- dict('dimensionality'=as.integer(3),
                 'float'=FALSE,
                 'input_image_type'=as.integer(0),
                 'interpolation'='Linear',
                 'transform_target_5'=transform_5_filename,
                 'transform_target_6'=transform_6_filename,
                 'verbose'=TRUE)
  
  ### run the job
  id_analysis <- gear$run(analysis_label = analysis_label, config = config, inputs = inputs, destination = this_session)
  aat_analysis_id[ii] <- id_analysis
  
}


# save analysis record to file --------------------------------------------

aat_analysis_table <- data.frame(label_subject_record,
                                 label_session_record, id_session_record, 
                                 rsq_analysis_id, mtcFSE_analysis_id, aat_analysis_id)
colnames(aat_analysis_table) <- c('label_subject', 
                                  'label_session', 'id_session', 
                                  'id_analysis_RSQ', 'id_analysis_mtcFSE', 'id_analysis_AAT')
write.csv(aat_analysis_table, 
          here('records', paste(today(), name_project_local, 'aat-FSE-to-MNI.csv', sep = '_')), 
          quote = FALSE, row.names = FALSE)
