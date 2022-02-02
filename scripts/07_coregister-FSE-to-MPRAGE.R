# this scrips runs the antsregistrationsynquick gear for the HRV-LC project
# specifically, this gear coregisters each session's native-space FSE scan
# to the corresponding whole brain template-coregistered MPRAGE scan
# (each session coreg carried out in a separate job)
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

### acquisition labels on flywheel
label_FSE <- 'acq-FSE_T1w'

### full path to record of scan resampling
file_record_resample <- list.files(here('records'), 
                                   pattern = '*resample-scans.csv', 
                                   full.names = TRUE)

### name of analysis (on flywheel) containing full MPRAGE template
analysis_mtc_MPR <- 'ANALYSISNAME'

### name of zip file within analysis containing full MPRAGE template
zip_mtc_MPR <- 'FILENAME.zip'

### analysis label
analysis_label <- paste(name_project_local, 'rsq-FSE-to-MPRAGE', today(), sep = '_')


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# load scan data ----------------------------------------------------------

session_data <- fread(file_record_resample)


# find mtc-mprage zip file ------------------------------------------------

for (ii in 1:length(project$analyses)) {
  if (project$analyses[[ii]]$label == analysis_mtc_MPR) {
    analysis <- project$analyses[[ii]]
  }
}
rm(ii)
for (ii in 1:length(analysis$files)) {
  if (analysis$files[[ii]]$name == zip_mtc_MPR) {
    input_fixed <- analysis$files[[ii]]
  } 
}
rm(ii)

zipInfo <- input_fixed$get_zip_info()


# create table with info about zip file contents --------------------------

files_num <- NULL
files_name <- NULL
files_type <- NULL
files_size <- NULL

for (ii in 1:length(zipInfo$members)) {
  files_num[ii] <- ii
  files_name[ii] <- zipInfo$members[[ii]]$path
  name_split <- str_split(zipInfo$members[[ii]]$path, 'resamp')
  suffix <- str_remove_all(name_split[[1]][2], '[[:digit:]]')
  suffix_stripped <- str_split(suffix, '.nii.gz')[[1]][1]
  files_type[ii] <- suffix_stripped
  files_size[ii] <- zipInfo$members[[ii]]$size/1e6
}
rm(ii)

# select only template-coregistered outputs
files_table <- data.frame(files_num, files_name, files_type, files_size)
files_table_main <- files_table %>%
  filter(files_type == 'WarpedToTemplate') %>%
  rowwise() %>%
  mutate(label_session = str_split(files_name, '_')[[1]][3],
         label_subject = str_c('sub-', str_split(files_name, '-')[[1]][3], sep = ''))


# set gear info -----------------------------------------------------------

gear <- fw$lookup('gears/ants-antsregistrationsynquick')


# set gear configuration defaults -----------------------------------------

gear$gear$config$fixed_image_zip_path$default = '';
gear$gear$config$histogram_bin_count$default = as.integer(32);
gear$gear$config$image_dimension$default = as.integer(3);
gear$gear$config$num_threads$default = as.integer(1);
gear$gear$config$precision_type$default = 'd';
gear$gear$config$spline_distance$default = as.integer(26);
gear$gear$config$transform_type$default = 's';
gear$gear$config$use_histogram_matching$default = as.integer(1);


# loop over mtc-mprage outputs, running rsq for each ----------------------

label_subject_record <- NULL
label_session_record <- NULL
id_session_record <- NULL
id_acq_FSE_record <- NULL
id_job_resampleImage_record <- NULL
output_resampleImage_record <- NULL
id_analysis_rsq_record <- NULL

for (ii in 2:nrow(files_table_main)) { #TEMP
  
  # find session corresponding to this subject & session
  label_subject_record[ii] <- files_table_main$label_subject[ii]
  label_session_record[ii] <- files_table_main$label_session[ii]
  this_session_data <- session_data %>%
    filter(label_acq == label_FSE) %>%
    filter(label_subject == label_subject_record[ii] & label_session == label_session_record[ii])
  id_session_record[ii] <- this_session_data$id_session
  id_acq_FSE_record[ii] <- this_session_data$id_acq
  id_job_resampleImage_record[ii] <- this_session_data$id_job_resampleImage
  output_resampleImage_record[ii] <- this_session_data$output_resampleImage
  
  # select resampled FSE file within session  
  this_acq <- fw$get(id_acq_FSE_record[ii])
  this_session <- fw$get(id_session_record[ii])
  
  for (hh in 1:length(this_acq$files)) {
    if (this_acq$files[[hh]]$name == output_resampleImage_record[ii]) {
      input_moving <- this_acq$files[[hh]]
    }
  }
  rm(hh)
  
  # set gear inputs
  inputs <- dict('fixed' = input_fixed,
                 'moving' = input_moving)
  
  # set gear configuration
  fixed_image_zip_path <- files_table_main$files_name[ii]  # path to template-coregistered MPRAGE
  out_prefix <- paste(label_subject_record[ii], 
                      label_session_record[ii], 'acq-FSE_T1w', 'resamp_', sep = '_')
  config <- dict('fixed_image_zip_path' = fixed_image_zip_path,
                  'histogram_bin_count' = as.integer(32),
                  'image_dimension' = as.integer(3),
                  'num_threads' = as.integer(1),
                  'out_prefix' = out_prefix,
                  'precision_type' = 'd',
                  'spline_distance' = as.integer(26),
                  'transform_type' = 's',
                  'use_histogram_matching' = as.integer(1))
  
  # run the gear
  id_analysis <- gear$run(analysis_label = analysis_label, 
                          config = config, inputs = inputs, 
                          destination = this_session)
  id_analysis_rsq_record[ii] <- id_analysis

}


# save record -------------------------------------------------------------

write.csv(rsq_analysis_table, 
          here('records', paste(today(), name_project_local, 'rsq-FSE-to-MPRAGE.csv', sep = '_')), 
          quote = FALSE, row.names = FALSE)
