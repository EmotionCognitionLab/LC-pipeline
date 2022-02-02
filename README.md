This repository contains scripts and instructions to run the semiautomated LC delineation pipeline on Flywheel using R and the Python SDK.

contact: shelby bachman ([sbachman@usc.edu](mailto:sbachman@usc.edu))

## prerequisites & dependencies

### project organization on Flywheel

- Scans for your project must be on Flywheel, in a single project, and must be named and organized following bids convention ([more info](https://bids-specification.readthedocs.io/en/stable/)). This section provides a minimal explanation of what that means.
- Subject labels are required and must be unique for each subject. Example subject label: `sub-1001`
- If you have more than one session per subject, the sessions must be named in bids convention and consistent across participants. Example session label: `ses-pre`
- Acquisition labels must be consistent across all sessions. Recommended acquisition labels: `T1w` for MPRAGE scans and `acq-FSE_T1w` for FSE scans.
- Furthermore, acquisition labels on Flywheel **must** match the acquisition label in the bids-formatted filenames. See example filenames below.
- Scan file naming **must** be consistent across all sessions. You can make things easier by keeping acquisition labels (see previous step) consistent with scan filenames. Example scan filenames: `sub-1001_ses-pre_T1w.nii.gz` for an MPRAGE acquisition labeled `T1w`, and `sub-1001_ses-pre_acq-FSE_T1w.nii.gz` for a FSE acquisition labeled `acq-FSE_T1w`.
- In case you are uploading bids-formatted data to a Flywheel project, the [bids uploader](https://docs.flywheel.io/hc/en-us/articles/360008162174-How-to-import-existing-BIDS-data) can be helpful.


### software

To run the pipeline, you will need the following installed on your local machine:

- R
- RStudio
- Python 3
- flywheel-sdk Python package (use `pip install flywheel-sdk` in the Terminal to install)
- R packages: reticulate, here, lubridate, dplyr, stringr, data.table, ANTsRCore
- ITK-snap (optional but recommended as a tool for visualizing outputs)

The [`reticulate`](https://github.com/rstudio/reticulate) package embeds a Python session within an R session, allowing us to use the flywheel-sdk python package from R. To get this working, you need to make sure `reticulate` is using the correct version of Python on your machine. On Mac/Linux, this is done as follows in the R command window.

As a start, check the version of python being used by default:

`Sys.which('python')`

If you have multiple versions of python on your machine or virtual environments that you want to use, you need to add the following line early in *each* of the scripts in the `scripts/` subdirectory. Note that by default, this line is not included in any of the scripts. So if you need it, remember to add it early in each script!

`use_python(Sys.which('python3'))`

You can find more information on python configuration with `reticulate` [here](https://rstudio.github.io/reticulate/articles/versions.html).


## directories


Before we turn to instructions for running the pipeline, this is a short aside about what exists in this repository. It has only one subdirectory to start:

`scripts`: all scripts for the pipeline are stored here. You will need to update parameters in *each* of these scripts in order to to run each step of the pipeline. This is described in the next section.

Additional subdirectories are created as you run the pipeline, and those are discussed below, in the order they are created.


## instructions

### part I: directory and project setup

1. Clone or download this repository and unzip it.
2. Rename the unzipped directory to match your project. For record-keeping, best practice is to use the name of your project on Flywheel, or a shorter version of it. (Throughout these instructions and the scripts, the string `PROJECTNAME` denotes your local project name.)
3. Create a new RStudio project in the new directory as follows. In RStudio, select `File` --> `New Project` --> `Existing Directory` and select the new directory. Then select `Create project`. This should create a file, `PROJECTNAME.Rproj` in your new directory. 

*Note #1*: Make sure that the python configuration you determined above is set correctly for this project.

*Note #2*: The scripts in this section depend on the directory being set up as an RStudio project. You can learn more about RStudio projects [here](https://support.rstudio.com/hc/en-us/articles/200526207-Using-RStudio-Projects).


### part II: running the pipeline

The steps in the pipeline are outlined below. Each step below is achieved with a single script. The instructions below provide more information about each step, point you to the relevant script, and point you to a record (if one is created at that step).

**For every script, you will need to update relevant parameters, in the section near the top labeled "Parameters".** Read each step carefully and **only** run steps on Flywheel when you are confident you have updated scripts with the correct parameters.

Make sure each step has finished before you begin the next. If you are new to running the pipeline, I recommend running the scripts line-by-line so that you understand what is going on. For some steps, in lieu of an `.R` script, instructions for starting the relevant analysis on Flywheel are provided in a markdown file.

*NOTE*: When you run each script, you will be prompted to enter your Flywheel API key in the R console. Copy and paste this into the console from the Flywheel website, but **never** hard code it into a script.

1. **Gather metadata for all sessions with available FSE and MPRAGE scans**

- script: `scripts/01_get-session-info.R`
- record: `records:/PROJECTNAME_session-info.csv`

This script creates a `.csv` file containing session metadata. It also creates a `records` subdirectory where records of various analyses in the pipeline are stored, and then stores the session metadata as `records/PROJECTNAME_session-info.csv`.

Note that this script finds all sessions with available MPRAGE and FSE scans. This is the best step at which to control which sessions are used for the pipeline. Sometimes, there are sessions to exclude due to a missing FSE scan or excessive motion or susceptibility artifact on the FSE scan. **It is recommended to manually inspect all your scans before running this pipeline, and exclude relevant sessions at this step, so they do not get included in the resulting .csv.** Add your own exclusions as needed after line 100 in the script.

2. **Resample FSE and MPRAGE scans to twice their native resolution**

- script: `scripts/02_resample-scans.R`
- Flywheel gear used: `ANTs: ResampleImage`
- record: `records/DATE_PROJECTNAME_resample-scans.csv`

3. **Gather resampled MPRAGE scan header information**

- script: `scripts/03_get-MPRAGE-header-data.R`
- record: `records/DATE_PROJECTNAME_MPR-header-data.csv`

Note that this script downloads resampled MPRAGE scans locally in order to extract header information. (If you figure out a way to extract header data from the resampled scans directly on Flywheel, please update the script and create a pull request!)

4. **Create MPRAGE template tag files**

- script: `scripts/04_create-MPRAGE-template-tag-file.R`
- records: 
	- record of MPRAGE scans included in initial template: `records/DATE_PROJECTNAME_scans-for-template-mprage-init.csv`
	- record of MPRAGE scans included in full template: `records/DATE_PROJECTNAME_scans-for-template-mprage.csv`

Note that this script uses the MPRAGE header information gathered in step 3 to select the resampled MPRAGE scans with qoffset_x, qoffset_y, and qoffset_z values all within a specified number of standard deviations of the mean (by default, 1). This subset of scans is fed into initial template building in step 5. An initial template based on scans with high spatial alignment helps the full template (step 6) have a good starting place for the initial affine registration.

Also note that this script creates 2 `.json` files that will be uploaded to Flywheel. When running the script, you will be prompted to modify each `.json` after it is created. Specifically, you should open each file and add square brackets (e.g. [ ]) around the entire contents of each file. The pipeline will not work if you do not complete this step.

5. **Build initial MPRAGE template**

- instructions: `scripts/05_construct-template_MPRAGE-init.md`
- Flywheel gear used: `ANTs: Multivariate Template Construction`
- (record saved on Flywheel)

Note for this and subsequent template-building steps: wait until template-building is done to proceed with the next step. Use the instructions in the markdown file to start the template-building analysis on Flywheel. All template-building steps are time-intensive and can take days or weeks. You should adjust parameters based on your own preferences and the size of your sample.

6. **Build full MPRAGE template**

- instructions: `scripts/06_construct-template_MPRAGE-full.md`
- Flywheel gear used: `ANTs: Multivariate Template Construction`
- (record saved on Flywheel)

7. **Coregister resampled FSE scans to MPRAGE template-coregistered MPRAGE scans**

- script: `scripts/07_coregister-FSE-to-MPRAGE.R`
- Flywheel gear used: `ANTs: RegistrationSyNQuick`
- record: `records/DATE_PROJECTNAME_rsq-FSE-to-MPRAGE.csv`

Note for this step that sometimes, random individual jobs fail (I have not figured out why). You should build in a step after this step and before the next, to check that all jobs completed and rerun the jobs that failed. If you do rerun jobs, make sure that you keep the analysis labels the same.

8. **Create FSE template tag file**

- script: `scripts/08_create-FSE-template-tag-file.R`
- record: list of FSE scans included in template-building is included in MPRAGE template-building record, at `records/DATE_PROJECTNAME_scans-for-template-mprage.csv`

Similar to step 4, this step creates 1 `.json` file that will be uploaded to Flywheel. When running the script, you will be prompted to modify the `.json` after it is created. Specifically, you should open the file and add square brackets (e.g. [ ]) around the entire contents of each file. The pipeline will not work if you do not complete this step.

9. **Build initial FSE template**

- instructions: `scripts/09_construct-template_FSE-init.md`
- Flywheel gear used: `ANTs: Multivariate Template Construction`
- (record saved on Flywheel)

10. **Build full FSE template**

- instructions: `scripts/10_construct-template_FSE-full.md`
- Flywheel gear used: `ANTs: Multivariate Template Construction`
- (record saved on Flywheel)

11. **Download MPRAGE & FSE templates, and create FSE lesion mask**

- script: `scripts/11_download-templates_create-lesion-mask.R`

This step creates a `templates` subdirectory and downloads group MPRAGE and FSE templates into the subdirectory. In subsequent steps, the templates are warped to relevant spaces and also downloaded into this subdirectory.

12. **Coregister FSE template to MPRAGE template**

- instructions: `scripts/12_antsRegSyN_FSE-to-MPR.md`
- Flywheel gear used: `ANTs: RegistrationSyN`
- (record saved on Flywheel)

This step and step 13 can take 24-36 hours each.

13. **Coregister MPRAGE template to MNI152 0.5mm linear space**

- instructions: `scripts/13_antsRegSyN_MPR-to-MNI.md`
- Flywheel gear used: `ANTs: RegistrationSyN`
- (record saved on Flywheel)

Note before this step you must upload a brain in the MNI space of interest (recommended: MNI152 0.5mm linear space). In the Flywheel project, navigate to Information --> Attachments and upload the `.nii.gz` file in the Attachments section. In the case that you only want to warp the FSE template into MPRAGE template space, you will need to adjust relevant parameters in this and subsequent steps, substituting the MPRAGE template file for the MNI brain image.

14. **Apply transforms to warp FSE template to MNI152 space**

- instructions: `scripts/14_aat-FSE-template-to-MNI.md`
- Flywheel gear used: `ANTs: Apply Transforms`
- (record saved on Flywheel)

15. **Download warped templates**

- script: `scripts/15_download-warped-templates.R`

Note that this step is for record-keeping, so that you have local copies of the created templates in each space of interest (respective template spaces as well as MNI).

16. **Apply transforms to warp resampled FSE scans to MNI152 space**

- script: `scripts/16_aat-FSE-to-MNI.R`
- Flywheel gear used: `ANTs: Apply Transforms`
- record: `records/DATE_PROJECTNAME_aat-FSE-to-MNI.csv`

17. **Download warped FSE scans**

- script: `scripts/17_download-warped-FSE.R`
- record: `records/DATE_PROJECTNAME_download-warped-FSE.csv`

## after running the pipeline

After running the above steps, you will have warped FSE scans for all sessions downloaded in the `scans_warped` subdirectory. LC contrast values should be calculated from these scans, either in a data-driven approach or by masking the warped scans with existing LC and reference maps (in the space to which you have warped FSE scans) and identifying hyperintensities in the masked regions.

In addition, templates (native and warped to each space of interest) will have been downloaded to the `templates` subdirectory. These can be used for visualization and validation purposes.

## notes

If you run into issues, or just want to make things more efficient, create a pull request!

As of September 2021, Flywheel indicated to me that they are no longer maintaining the R interface to the `flywheel-sdk` package. This complicates two steps of the pipeline: downloading MPRAGE scans to allocate header information, and downloading the final warped FSE scans for ratio extraction. What happens is that the connection to Flywheel breaks after downloading a batch of scans. The workaround they suggested to me (and which I implemented in these scripts) is a try-catch loop which reconnects if the connection is lost, hence the rather complicated loop to download scans in steps 3 and 17. In the next few months, I hope to create another version of this pipeline in python, using the `flywheel-sdk` package directly.


