this file contains instructions on how to create
a full MPRAGE template
written by shelby bachman, sbachman@usc.edu

## GETTING STARTED

- log in to flywheel
- navigate to your flywheel project
- Navigate to Analyses --> Run Analysis Gear
- Select ANTs: Multivariate Template Construction

### Set inputs and analysis label
- tag_file: Files --> select the tag file you created for the full MPRAGE template (ends in *mtc-MPRAGE.json)
- template: Analyses --> initial template-building analysis --> mtc0_template0.nii.gz
- Analysis Label: PROJECTNAME_mtc-MPRAGE_DATE

### Set configuration
- cpu_cores: 35
- gradient_step_size: 0.25
- image_dimension: 3
- input_file_pattern: *.nii.gz
- iteration_limit: 6
- log_disk_usage: false
- max_iterations: 30x90x20
- modality_weights: 1
- n4_bias_field_correction: 1
- num_modalities: 1
- out_prefix: mtc_
- parallel_computation: 2
- registration_similarity_metric: CC
- rigid_body_registration: 0
- tag: (tag from tag file)
- transformation_model_type: GR
- update_template_with_full_affine: 1

### Select "Run gear" to start the analysis
