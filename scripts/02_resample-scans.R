# this script runs the resampleImage gear on Flywheel
# to resample FSE and MPRAGE scans to twice their native resolution
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
label_MPRAGE <- 'T1w'

### dimensions of resampled FSE and MPRAGE scans
### (note: this should be twice the original resolution)
dim_resamp_FSE <- 'AxBxC' # example: '1024x1024x22'
dim_resamp_MPRAGE <- 'AxBxC'  # example: '352x448x512'


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)
rm(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# set gear info -----------------------------------------------------------

gear <- fw$lookup('gears/ants-resampleimage')


# load session data -------------------------------------------------------

data_sessions <- fread(here('records', 
                            paste(name_project_local, '_session-info.csv', sep = '')))


# loop over sessions and acquisitions and run gear ------------------------

record_resamp <- NULL

for (ii in 1:nrow(data_sessions)) {
  
  # extract session & subject label for this session
  session <- fw$get(data_sessions$id_session[ii])
  this_timepoint <- session$label
  this_subID <- session$subject$label
  
  # get list & acquisitions for this session and loop over
  # for each acquisition, upsample FSE and MPRAGE scans
  acquisitions <- session$acquisitions()
  
  for (hh in 1:length(acquisitions)) {
    
    if (acquisitions[[hh]]$label == label_FSE) {

      # set FSE acquisition
      acq_FSE <- acquisitions[[hh]]
      acq_id_FSE <- acq_FSE$id
      
      # expected FSE filename
      expected_FSE <- paste(this_subID, '_', this_timepoint, '_', label_FSE, '.nii.gz', sep = '')
      output_FSE <- paste(this_subID, '_', this_timepoint, '_', label_FSE, '_resamp.nii.gz', sep = '')
      
      # find the FSE scan & run ResampleImage gear
      for (jj in 1:length(acq_FSE$files)) {
        if (acq_FSE$files[[jj]]$name == expected_FSE) {
          
          # find input file
          input_FSE <- acq_FSE$files[[jj]]
          
          # set gear inputs & configuration
          inputs <- dict('inputImage' = input_FSE)
          config <- dict('MxNxO'=dim_resamp_FSE,
                         'image_dimension'=as.integer(3),
                         'interpolation_type'='0',
                         'output_image'=output_FSE,
                         'pixel_type'=as.integer(6),
                         'size_or_spacing'=TRUE)
          
          # run the gear
          resamp_job_id_FSE <- gear$run(config = config, inputs = inputs, destination = acq_FSE)
          message(paste('running ResampleImage for file: ', expected_FSE, sep = ''))
          
          record_resamp <- rbind(record_resamp, c(this_subID, this_timepoint, data_sessions$id_session[ii], label_FSE,
                                   acq_id_FSE, resamp_job_id_FSE, output_FSE))
          rm(input_FSE, inputs, config)
          
        }
      }
      rm(jj)
      
    } else if (acquisitions[[hh]]$label == label_MPRAGE) {
      
      # set MPRAGE acquisition
      acq_MPRAGE <- acquisitions[[hh]]
      acq_id_MPRAGE <- acq_MPRAGE$id
      
      # expected MPRAGE filename
      expected_MPRAGE <- paste(this_subID, '_', this_timepoint, '_', label_MPRAGE, '.nii.gz', sep = '')
      output_MPRAGE <- paste(this_subID, '_', this_timepoint, '_', label_MPRAGE, '_resamp.nii.gz', sep = '')
      
      # find the MPRAGE scan & run ResampleImage gear
      for (jj in 1:length(acq_MPRAGE$files)) {
        if (acq_MPRAGE$files[[jj]]$name == expected_MPRAGE) {
          
          # find input file
          input_MPRAGE <- acq_MPRAGE$files[[jj]]
          
          # set gear inputs & configuration
          inputs <- dict('inputImage' = input_MPRAGE)
          config <- dict('MxNxO'=dim_resamp_MPRAGE,
                         'image_dimension'=as.integer(3),
                         'interpolation_type'='0',
                         'output_image'=output_MPRAGE,
                         'pixel_type'=as.integer(6),
                         'size_or_spacing'=TRUE)
          
          # run the gear
          resamp_job_id_MPRAGE <- gear$run(config = config, inputs = inputs, destination = acq_MPRAGE)
          
          message(paste('running ResampleImage for file: ', expected_MPRAGE, sep = ''))
          
          # store record of analysis
          record_resamp <- rbind(record_resamp, c(this_subID, this_timepoint, data_sessions$id_session[ii], label_MPRAGE,
                                                      acq_id_MPRAGE, resamp_job_id_MPRAGE, output_MPRAGE))
          rm(input_MPRAGE, inputs, config)
        }
      }
      rm(jj)
      
    }
  }
  
  rm(session, acquisitions, this_timepoint, this_subID)
  
}


# save record of jobs run -------------------------------------------------

record_resamp <- as.data.frame(record_resamp)
names(record_resamp) <- c('label_subject', 'label_session', 'id_session', 
                          'label_acq', 'id_acq', 
                          'id_job_resampleImage', 'output_resampleImage')

write.csv(record_resamp, 
          here('records', paste(today(), '_', name_project_local, '_resample-scans.csv', sep = '')),
          quote = FALSE, row.names = FALSE)
