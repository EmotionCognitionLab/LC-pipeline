this file contains instructions on how to create
an initial MPRAGE template
written by shelby bachman, sbachman@usc.edu

## GETTING STARTED

- log in to flywheel
- navigate to your flywheel project
- Navigate to Analyses --> Run Analysis Gear
- Select ANTs: Multivariate Template Construction

### Set inputs and analysis label
- tag_file: Files --> select the tag file you created for the initial MPRAGE template (ends in *mtc-MPRAGE_init.json)
- template: (empty)
- Analysis Label: PROJECTNAME_mtc0-MPRAGE_DATE

### Set configuration
- cpu_cores: 55
- gradient_step_size: 0.25
- image_dimension: 3
- input_file_pattern: *.nii.gz
- iteration_limit: 6
- log_disk_usage: false
- max_iterations: 1x0x0
- modality_weights: 1
- n4_bias_field_correction: 1
- num_modalities: 1
- out_prefix: mtc0_
- parallel_computation: 2
- registration_similarity_metric: CC
- rigid_body_registration: 1
- tag: (tag from tag file)
- transformation_model_type: GR
- update_template_with_full_affine: 1

### Select "Run gear" to start the analysis
