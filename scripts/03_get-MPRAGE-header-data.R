# this script downloads resampled MPRAGE scans from Flywheel
# and gathers their header data
# written by shelby bachman, sbachman@usc.edu


# setup -------------------------------------------------------------------

rm(list = ls())
library(here)
library(reticulate)
library(stringr)
library(data.table)
library(dplyr)
library(lubridate)
library(oro.nifti)
flywheel <- import('flywheel')


# parameters --------------------------------------------------------------

### name of group on flywheel
name_group <- 'emocog'

### name of project on flywheel
name_project <- 'PROJECT'

### shorthand version of project name, for saving local filenames
name_project_local <- 'PROJECTNAME'

### acquisition labels on flywheel
label_MPRAGE <- 'T1w'

### full path to local directory where resampled MPR scans should be downloaded
# (if this directory doesn't exist, it will be created)
path_download_MPR <- here('nifti_MPR-resamp')


# connect to flywheel -----------------------------------------------------

my_key <- readline(prompt="Enter flywheel API key: ")
fw <- flywheel$Client(my_key)


# find project ------------------------------------------------------------

project <- fw$lookup(paste(name_group, name_project, sep = '/'))


# create local path for downloads as needed -------------------------------

if (!dir.exists(path_download_MPR)) {
  dir.create(path_download_MPR)
}


# load session data -------------------------------------------------------

data_sessions <- fread(here('records', 
                            paste(name_project_local, '_session-info.csv', sep = '')))


# loop over sessions and extract MPR acquisition info ---------------------

acq_MPRAGE <- NULL
filename_MPRAGE_fw <- NULL
filename_MPRAGE_local <- NULL

for (ii in 1:nrow(data_sessions)) {
  
  # find session
  session <- fw$get(data_sessions$id_session[ii])
  this_subID <- session$subject$label
  this_timepoint <- session$label
  
  # find ID of MPRAGE acquisition
  acquisitions <- session$acquisitions()
  
  for (hh in 1:length(acquisitions)) {
    if (acquisitions[[hh]]$label == label_MPRAGE) {
      acq_MPRAGE[ii] <- acquisitions[[hh]]$id
    } 
  }
  
  # store resampled MPRAGE filename on flywheel
  filename_MPRAGE_fw[ii] <- paste(this_subID, this_timepoint, label_MPRAGE, 'resamp.nii.gz', sep = '_')
    
  # store full path of downloaded version of MPRAGE
  filename_MPRAGE_local[ii] <- paste(path_download_MPR, '/', 
                              paste(this_subID, this_timepoint, label_MPRAGE, 'resamp.nii.gz', sep = '_'),
                              sep = '')
  
  rm(acquisitions)
}


# function to download resampled MPRAGE scan ------------------------------

# NOTE: the try-catch loop is a workaround to handle connection errors 
# this happens with the R interface to flywheel-sdk after several successive downloads

download_mpr <- function(api_key, acq_id, filename_fw, filename_local, idx) {
  out <- tryCatch(
    expr = {
      
      acquisition <- fw$get(acq_id)
      acquisition$download_file(filename_fw, filename_local)
      print(paste('idx: ', idx, '; DOWNLOADED FILE: ', filename_fw, sep = ''))
      
    },
    error = function(e) {
      
      print(paste('idx: ', idx, '; error caught. reconnecting to flywheel!', sep = ''))
      # -- if error is encountered --
      # reconnect to flywheel again before downloading
      fw <- flywheel$Client(api_key)

      acquisition <- fw$get(acq_id)
      acquisition$download_file(filename_fw, filename_local)
      print(paste('idx: ', idx, '; DOWNLOADED FILE: ', filename_fw, sep = ''))
      
    },
    warning = function(e) {
      
      print(paste('idx: ', idx, '; warning caught. reconnecting to flywheel!', sep = ''))
      # -- if warning is caught -- 
      # reconnect to flywheel again before downloading
      fw <- flywheel$Client(api_key)

      acquisition <- fw$get(acq_id)
      acquisition$download_file(filename_fw, filename_local)
      print(paste('idx: ', idx, '; DOWNLOADED FILE: ', filename_fw, sep = ''))
      
    }
  )
}


# loop over MPR acquisitions and download scans ---------------------------

batch_size <- 10
n_batches <- ceiling(nrow(data_sessions) / batch_size)
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
    download_mpr(my_key, acq_MPRAGE[jj], filename_MPRAGE_fw[jj], filename_MPRAGE_local[jj], jj)
    
    if (jj == nrow(data_sessions)) {
      break
    }
     
  }
  rm(jj)
  
  # after batch is run, pause for 30 seconds
  Sys.sleep(30)
    
}

rm(my_key, project, acq_MPRAGE, this_subID, this_timepoint, ii, fw, download_mpr)


# for each downloaded scan, read and save header data ---------------------

MPRAGE_scans <- list.files(path_download_MPR)

filename <- NULL
label_subject <- NULL
label_session <- NULL
qoffset_x <- NULL
qoffset_y <- NULL
qoffset_z <- NULL

for (ii in 1:length(MPRAGE_scans)) {
  
  filename[ii] <- MPRAGE_scans[ii]
  print(paste('gathering header data for ', filename[ii], ' ...', sep = ''))
  
  temp <- str_split(MPRAGE_scans[ii], '_')[[1]]
  label_subject[ii] <- temp[1]
  label_session[ii] <- temp[2]
  temp <- readNIfTI(paste(path_download_MPR, '/', MPRAGE_scans[ii], sep = ''), reorient = FALSE)
  qoffset_x[ii] <- temp@qoffset_x
  qoffset_y[ii] <- temp@qoffset_y
  qoffset_z[ii] <- temp@qoffset_z
  
}

# join as dataframe
data_MPRAGE_hdr <- data.frame(filename, label_subject, label_session,
                         qoffset_x, qoffset_y, qoffset_z) 


# save MPRAGE header data -------------------------------------------------

write.csv(MPRAGE_hdr, 
          here('records', paste(today(), name_project_local, 'MPRAGE-header-data.csv', sep = '_')),
          quote = FALSE, row.names = FALSE)
