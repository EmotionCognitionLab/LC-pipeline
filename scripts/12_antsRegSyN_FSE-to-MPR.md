this file contains instructions on how to 
coregister the FSE template to the MPRAGE template
written by shelby bachman, sbachman@usc.edu

## GETTING STARTED

- log in to flywheel
- navigate to your flywheel project
- Navigate to Analyses --> Run Analysis Gear
- Select ANTs: RegistrationSyN

### Set inputs and analysis label

- fixed: Analyses --> full MPRAGE template-building analysis --> mtc_template0.nii.gz
- mask1: Files --> PROJECTNAME_template-FSE_mask.nii.gz
- moving: Analyses --> full FSE template-building analysis --> mtc_template0.nii.gz
- Analysis Label: PROJECTNAME_rs-FSE-to-MPR_DATE

### Set configuration
- collapse_output_transforms: 1
- image_dimension: 3
- log_resource_usage_every_N_seconds: 0
- num_threads: 1
- out_prefix: PROJECTNAME_FSE-to-MPR_
- precision_type: d
- radius: 4
- spline_distance: 26
- transform_type: s
- use_histogram_matching: 1

### Select "Run gear" to start the analysis
