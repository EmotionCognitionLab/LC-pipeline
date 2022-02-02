this file contains instructions on how to 
apply transforms to warp the FSE template to MNI space
written by shelby bachman, sbachman@usc.edu

## GETTING STARTED

- log in to flywheel
- navigate to your flywheel project
- Navigate to Analyses --> Run Analysis Gear
- Select ANTs: Apply Transforms

### Set inputs and analysis label

- input_file: Analyses --> full FSE template-building analysis --> mtc_template0.nii.gz
- reference_file: Files --> MNI brain of interest (must upload in advance)
- transform_file_1: Analyses --> rs-MPR-to-MNI analysis --> PROJECTNAME_MPR-to-MNI_1Warp.nii.gz 
- transform_file_2: Analyses --> rs-MPR-to-MNI analysis --> PROJECTNAME_MPR-to-MNI_0GenericAffine.mat 
- transform_file_3: Analyses --> rs-FSE-to-MPR analysis --> PROJECTNAME_FSE-to-MPR_1Warp.nii.gz
- transform_file_4: Analyses --> rs-FSE-to-MPR analysis --> PROJECTNAME_FSE-to-MPR_0GenericAffine.nii.gz
- Analysis Label: PROJECTNAME_aat-FSE-to-MNI_DATE

### Set configuration
- dimensionality: 3
- float: false
- input_image_type: 0
- interpolation: Linear
- transform_target_1:
- transform_target_2:
- transform_target_3:
- transform_target_4:
- transform_target_5:
- transform_target_6:
- transform_target_7:
- transform_target_8:
- verbose: true

### Select "Run gear" to start the analysis
