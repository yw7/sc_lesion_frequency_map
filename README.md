# Spinal Cord Lesion Frequency Map (LFM) with SCT

Pipline to make Lesion Frequency Map (LFM) along the spinal cord using SCT.

It's a bash script inspired by the Python code in [neuropoly/lesion-mapping](https://github.com/neuropoly/lesion-mapping).

- [Dependencies](#dependencies)
- [Dataset structure](#dataset-structure)
- [Prerequirments](#prerequirments)
- [Steps](#steps)
- [Usage](#usage)
- [Usage](#usage)
- [Examples](#examples)

## Dependencies
- [Spinal Cord Toolbox (SCT)](https://spinalcordtoolbox.com/)

## Dataset structure
- Similar to the result of running [sct_run_batch](https://spinalcordtoolbox.com/user_section/command-line.html#sct-run-batch).

## Pre-Requirements
Before running the script you should have in each subject's folder the following:
1. Spinal cord segmentation (Can be generated with [sct_deepseg_sc](https://spinalcordtoolbox.com/user_section/command-line.html#sct-deepseg-sc)).
1. Lesions segmentation (Can be generated with [sct_deepseg_lesion](https://spinalcordtoolbox.com/user_section/command-line.html#sct-deepseg-lesion)).
1. Warping fields to template space (Can be generated with [sct_register_to_template](https://spinalcordtoolbox.com/user_section/command-line.html#sct-register-to-template)).

## Steps
The script perform the following steps:
- for each subject:
  - Look in subject folder for all cord segmentations.
  - Look in subject folder for matching warping fields.
  - Merge all cord segmentations into the template space using the warping fields (nn interpolation).
    - create `<subject><cord suffix>_template.nii.gz`.
  - Look in subject folder for all lesions segmentations.
  - Look in subject folder for matching warping fields.
  - Merge all lesions segmentations into the template space using the warping fields(linear interpolation).
    - create `<subject><lesions suffix>_template.nii.gz`.
- Then:
  - Sum all cord segmentation.
  - Sum all lesions segmentation.
  - Generate LFM with sum of all lesions divided by the sum of all cords.

## Usage
~~~
make_lfm.sh \
    [-d <Data directory. default: "output/data_processed">] \
    [-s <Subjects file - text file with subjects names, subject per line. default: "subjects.txt">] \
    [-f <Data directory in subject folder. default: "anat">] \
    [-i <Image pattern (Will look also with "${SUBJECT}_" as prefix by default). default: "t2w">] \
    [-l <Lesions segmentation file suffix (Must be a binary map). default: "_lesionseg">] \
    [-c <Spinal cord segmentation file suffix (Must be a binary map). default: "_seg">] \
    [-w <Warping fields to template space file suffix pattern. default: ".*?warp_anat2template">] \
    [-o <Output LFM file. default: "LFM.nii.gz">] \
    [-r <Overwrite (0/1). If 1, the analisis will run again even if files exist. default: 1>] \
    [-m <Set all spinal cord area wich is not covered by all subject's cord segmentation to 0 (0/1). default: 1>] \
    [-t <Template prefix. default: "${SCT_DIR}/data/PAM50/template/PAM50_">] \
    [-a <Min level of sponal cord to be in result. default: 1 (C1)>] \
    [-b <Max level of sponal cord to be in result. default: 20 (T12)>]
~~~

## How to run

For the following dataset:
~~~
- ~/
  - some_study/
    - output/
      - data_processed/
        - sub-1/
          - anat/
            - t2.nii.gz
            - t2_seg.nii.gz # cord mask (binary)
            - t2_lesionseg.nii.gz # lesion mask (binary)
            - t2_warp_anat2template.nii.gz # warping fields to template
        - sub-2/
          - anat/
            - t2.nii.gz
            - t2_seg.nii.gz # cord mask (binary)
            - t2_lesionseg.nii.gz # lesion mask (binary)
            - t2_warp_anat2template.nii.gz # warping fields to template
        - ...
~~~

- Download (or `git clone`) this repository:
~~~
git clone https://github.com/yw7/sc_lesion_frequency_map.git
~~~

- Add executable permissions:
~~~
chmod +x sc_lesion_frequency_map/make_lfm.sh
~~~

- Make `subjects_all.txt` (You can edit this file to make LFM for subgroup of subjects):
~~~
ls some_study/output/data_processed > some_study/subjects_all.txt
~~~

- Run the script (make LFM for Spinal Cord level C1 to C7):
~~~
sc_lesion_frequency_map/make_lfm.sh -d some_study/output/data_processed -s some_study/subjects_all.txt -o some_study/LFM_all.nii.gz -i t2 -a 1 -b 7
~~~

## More Examples
Do not set all spinal cord area wich is not covered by all subject's cord segmentation to 0 (If some template voxel cover by some subjects it's value in the LFM will be the lesion frequency among those subjects):
~~~
sc_lesion_frequency_map/make_lfm.sh -d some_study/output/data_processed -s some_study/subjects_all.txt -o some_study/LFM_all.nii.gz -i t2 -m 0 -a 1 -b 7
~~~
Without overwriting previous analysis (For cases when running the script multiple time with overlaping groups, do not transform segmentations to template again):
~~~
sc_lesion_frequency_map/make_lfm.sh -d some_study/output/data_processed -s some_study/subjects_all.txt -o some_study/LFM_group1.nii.gz -i t2 -a 1 -b 7 -r 0
~~~
If the files are in subject's folder (not in 'anat' folder):
~~~
sc_lesion_frequency_map/make_lfm.sh -d some_study/output/data_processed -s some_study/subjects_all.txt -o some_study/LFM_group1.nii.gz -i t2 -d . -f "" -m 0 -r 0 -a 1 -b 7
~~~

