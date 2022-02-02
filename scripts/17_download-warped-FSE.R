# this script downloads FSE scans warped to MNI space from Flywheel
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

### local path to .csv containing record of ants-apply transforms jobs
# in which resampled FSE scans were warped to MNI space
file_aat <- list.files(here('records'), 
                        pattern = '*aat-FSE-to-MNI.csv', 
                        full.names = TRUE)


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# read ants apply-transforms record data ----------------------------------

data_aat <- fread(file_aat)


# create local path for downloads as needed -------------------------------

if (!dir.exists(here('scans_warped'))) {
  dir.create(here('scans_warped'))
}


# function to download resampled MPRAGE scan ------------------------------

# NOTE: the try-catch loop is a workaround to handle connection errors 
# this happens with the R interface to flywheel-sdk after several successive downloads

download_FSE <- function(api_key, analysis_id, filename_fw, filename_local, idx) {
  out <- tryCatch(
    expr = {
      
      analysis <- fw$get(analysis_id)
      analysis$download_file(filename_fw, filename_local)
      print(paste('idx: ', idx, '; DOWNLOADED FILE: ', filename_fw, sep = ''))
      rm(analysis)
      
    },
    error = function(e) {
      
      print(paste('idx: ', idx, '; error caught. reconnecting to flywheel!', sep = ''))
      # -- if error is encountered --
      # reconnect to flywheel again before downloading
      fw <- flywheel$Client(api_key)
      
      analysis <- fw$get(analysis_id)
      analysis$download_file(filename_fw, filename_local)
      print(paste('idx: ', idx, '; DOWNLOADED FILE: ', filename_fw, sep = ''))
      rm(analysis)
      
    },
    warning = function(e) {
      
      print(paste('idx: ', idx, '; warning caught. reconnecting to flywheel!', sep = ''))
      # -- if warning is caught -- 
      # reconnect to flywheel again before downloading
      fw <- flywheel$Client(api_key)
      
      analysis <- fw$get(analysis_id)
      analysis$download_file(filename_fw, filename_local)
      print(paste('idx: ', idx, '; DOWNLOADED FILE: ', filename_fw, sep = ''))
      rm(analysis)
      
    }
  )
}


# loop over analyses & download outputs -----------------------------------

label_subject <- NULL
label_session <- NULL
id_analysis_AAT <- NULL
file_warped_orig <- NULL
file_warped_renamed <- NULL
file_warped_renamed_full <- NULL

for (ii in 1:nrow(data_aat)) {
  
  # extract metadata from table
  label_subject[ii] <- data_aat$label_subject[ii]
  label_session[ii] <- data_aat$label_session[ii]
  
  # set warped filename & name for local saving
  file_warped_orig[ii] <- paste(label_subject[ii], 
                                label_session[ii], 
                                label_FSE,         
                                'resamp_warped.nii.gz',
                                sep = '_')
  file_warped_renamed[ii] <- paste(label_subject[ii], 
                                   label_session[ii],
                                   label_FSE,     
                                   'resamp_warped-MNI.nii.gz',
                                   sep = '_')
  file_warped_renamed_full[ii] <- here('scans_warped', file_warped_renamed[ii])
  
  # analysis from which to download
  id_analysis_AAT[ii] <- data_aat$id_analysis_AAT[ii]
  
}


# loop over FSE acquisitions and download scans ---------------------------

batch_size <- 10
n_batches <- ceiling(nrow(data_aat) / batch_size)
starting_indices <- rep(1, n_batches) + seq(from = 0, 
                                            by = batch_size,
                                            length.out = n_batches)

for (ii in 1:n_batches) {
  
  # set starting index and all indices for this batch
  this_start <- starting_indices[ii]
  indices <- this_start:(this_start + (batch_size-1))
  
  # set indices to run in this batch
  
  print(paste('----- STARTING BATCH ', ii, ' -----', sep = ''))
  
  # loop over indices in this batch
  for (jj in indices) {
    
    print(paste('-------------- INDEX ', jj, ' --------------', sep = ''))
    download_FSE(my_key, id_analysis_AAT[jj], file_warped_orig[jj], file_warped_renamed_full[jj], jj)
    
    if (jj == nrow(data_aat)) {
      break
    }
    
  }
  rm(jj)
  
  # after batch is run, pause for 30 seconds
  Sys.sleep(30)
  
}

# save download record ----------------------------------------------------

MNI_download_record <- data.frame(
  label_subject, label_session, id_analysis_AAT, 
  file_warped_orig, file_warped_renamed, file_warped_renamed_full)

write.csv(MNI_download_record,
          here('records', paste(today(), paste(name_project_local, '_download-warped-FSE.csv', sep = ''), sep = '_')),
          quote = FALSE, row.names = FALSE)

