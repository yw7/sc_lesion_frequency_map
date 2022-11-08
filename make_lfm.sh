#!/bin/bash
#
# Pipline to make Lesion Frequency Map (LFM) along the spinal cord using sct.
#
# Dependencies:
#   Spinal Cord Toolbox (SCT)
#
# - Before running the script you should have in each subject's folder the following:
#   2. Spinal cord segmentation (Can be generated with sct_deepseg_sc).
#   3. Lesions segmentation (Can be generated with sct_deepseg_lesion).
#   4. Warping fields to template space (Can be generated with sct_register_to_template).
#
# The script perform the following steps:
#  for each subject:
#   Look in subject folder for all cord segmentations.
#   Look in subject folder for matching warping fields.
#   Merge all cord segmentations into the template space using the warping fields (nn interpolation).
#      create "<subject><cord suffix>_template.nii.gz".
#   Look in subject folder for all lesions segmentations.
#   Look in subject folder for matching warping fields.
#   Merge all lesions segmentations into the template space using the warping fields(linear interpolation).
#      create "<subject><lesions suffix>_template.nii.gz".
#  Then:
#   Sum all cord segmentation.
#   Sum all lesions segmentation.
#   Generate LFM with sum of all lesions divided by the sum of all cords.
#
# Usage:
# make_lfm.sh \
#     [-d <Data directory. default: "output/data_processed">] \
#     [-s <Subjects file - text file with subjects names, subject per line. default: "subjects.txt">] \
#     [-f <Data directory in subject folder. default: "anat">] \
#     [-i <Image pattern (Will look also with "${SUBJECT}_" as prefix by default). default: "t2w">] \
#     [-l <Lesions segmentation file suffix (Must be a binary map). default: "_lesionseg">] \
#     [-c <Spinal cord segmentation file suffix (Must be a binary map). default: "_seg">] \
#     [-w <Warping fields to template space file suffix pattern. default: ".*?warp_anat2template">] \
#     [-o <Output LFM file. default: "LFM.nii.gz">] \
#     [-r <Overwrite (0/1). If 1, the analisis will run again even if files exist. default: 1>] \
#     [-m <Set all spinal cord area wich is not covered by all subject's cord segmentation to 0 (0/1). default: 1>] \
#     [-t <Template prefix. default: "${SCT_DIR}/data/PAM50/template/PAM50_">] \
#     [-a <Min level of sponal cord to be in result. default: 1 (C1)>] \
#     [-b <Max level of sponal cord to be in result. default: 20 (T12)>]
#

# BASH SETTINGS
# ======================================================================================================================

# Uncomment for full verbose
# set -v

# Immediately exit if error
set -e

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

# GET PARAMS
# ======================================================================================================================

WDIR=$(pwd)
DATA_DIR="output/data_processed"
SUBJECTS_FILE="subjects.txt"
SUBJECT_DATA_DIR="anat"
FILE_PAT="t2w"
LESIONS_EXT="_lesionseg"
CORD_EXT="_seg"
WARP_PAT=".*?warp_anat2template"
OUT_FILE="LFM.nii.gz"
OVERWRITE=1
MASK_TO_COVERAGE=1
TEMPLATE="${SCT_DIR}/data/PAM50/template/PAM50_"
LEVEL_MIN=1
LEVEL_MAX=20

# Get command parameters
while getopts d:s:f:i:l:c:w:o:r:m:t:a:b: flag
do
  case "${flag}" in
    d) DATA_DIR=${OPTARG};;
    s) SUBJECTS_FILE=${OPTARG};;
    f) SUBJECT_DATA_DIR=${OPTARG};;
    i) FILE_PAT=${OPTARG};;
    l) LESIONS_EXT=${OPTARG};;
    c) CORD_EXT=${OPTARG};;
    w) WARP_PAT=${OPTARG};;
    o) OUT_FILE=${OPTARG};;
    r) OVERWRITE=${OPTARG};;
    m) MASK_TO_COVERAGE=${OPTARG};;
    t) TEMPLATE=${OPTARG};;
    a) LEVEL_MIN=${OPTARG};;
    b) LEVEL_MAX=${OPTARG};;
  esac
done


WDIR=$(realpath "${WDIR}")
DATA_DIR=$(realpath "${DATA_DIR}")
SUBJECTS_FILE=$(realpath "${SUBJECTS_FILE}")
OUT_FILE=$(realpath "${OUT_FILE}")
TEMPLATE=$(realpath "${TEMPLATE}")

echo ""
echo "Running with the following parameters:"
echo "WDIR=${WDIR}"
echo "DATA_DIR=${DATA_DIR}"
echo "SUBJECTS_FILE=${SUBJECTS_FILE}"
echo "SUBJECT_DATA_DIR=${SUBJECT_DATA_DIR}"
echo "FILE_PAT=${FILE_PAT}"
echo "LESIONS_EXT=${LESIONS_EXT}"
echo "CORD_EXT=${CORD_EXT}"
echo "WARP_PAT=${WARP_PAT}"
echo "OUT_FILE=${OUT_FILE}"
echo "OVERWRITE=${OVERWRITE}"
echo "MASK_TO_COVERAGE=${MASK_TO_COVERAGE}"
echo "TEMPLATE=${TEMPLATE}"
echo "LEVEL_MIN=${LEVEL_MIN}"
echo "LEVEL_MAX=${LEVEL_MAX}"
echo ""

# SCRIPT STARTS HERE
# ======================================================================================================================

unset LIST_CORD_SEG_TEMPLATE
unset LIST_LESIONS_SEG_TEMPLATE

# Get subjects data
# ----------------------------------------------------------------------------------------------------------------------

# Loop over subjects, find the coresponding files and move them into the template space using the warping fields.
for SUBJECT in $(cat ${SUBJECTS_FILE}); do

    if [[ "${SUBJECT}" == "" ]]; then
        continue
    fi

    echo -e "\nworking on:\nSUBJECT=${SUBJECT}"

    cd "${DATA_DIR}/${SUBJECT}/${SUBJECT_DATA_DIR}"

    SUB_CORD_SEG_TEMPLATE="${SUBJECT}${CORD_EXT}_template.nii.gz"
    SUB_LESIONS_SEG_TEMPLATE="${SUBJECT}${LESIONS_EXT}_template.nii.gz"

    if [[ ! -f ${SUB_CORD_SEG_TEMPLATE} || ! -f ${SUB_CORD_SEG_TEMPLATE} || ${OVERWRITE} == 1 ]]; then

        # Find cord and lesions segmentation and matching warping fields
        for EXT in ${CORD_EXT} ${LESIONS_EXT}; do
            
            echo -e "\nEXT=${EXT}"

            unset SUB_LIST_SEG
            unset SUB_LIST_WARP

            echo -e "\nLooking for segmentation files:"

            for SEG in $(find -type f -regextype posix-egrep -regex "\./(${SUBJECT}_)?${FILE_PAT}${EXT}.nii.gz"); do
            
                SUB_LIST_SEG+=("${SEG}")
                echo -e "\nSEG=${SEG}"
                
                echo -e "\nLooking for matching warping fields:"
                
                for WARP in $(find -type f -regextype posix-egrep -regex "${SEG%"${EXT}.nii.gz"}${WARP_PAT}.nii.gz"); do
                
                    SUB_LIST_WARP+=("${WARP}")
                    echo -e "\nWARP=${WARP}"

                done

                # If no warping fields to destination file found for this segmentation try without FILE_PAT
                if [[ ${#SUB_LIST_WARP[@]} != ${#SUB_LIST_SEG[@]} ]]; then
                    
                    for WARP in $(find -type f -regextype posix-egrep -regex "\./(${SUBJECT}_)?${WARP_PAT}.nii.gz"); do
                    
                        SUB_LIST_WARP+=("${WARP}")
                        echo -e "\nWARP=${WARP}"

                    done

                fi

                # Exit if not exactly 1 warping fields to destination file found for this segmentation
                if [[ ${#SUB_LIST_WARP[@]} != ${#SUB_LIST_SEG[@]} ]]; then

                    echo "Not exactly 1 warping fields to destination file found for ${SEG}"
                    exit 1

                fi

            done

            echo -e "Found ${#SUB_LIST_SEG[@]} segmentation files"

            # Exit if no segmentation file found for this subject
            if [[ ${#SUB_LIST_SEG[@]} < 1 ]]; then

                echo "Not segmentation file found for ${SUBJECT}"
                exit 1

            fi

            echo -e "\nMoving segmentations into template space"

            # Interpolation for warping the segmentations to the destination image.
            INTERP="linear"

            # For spinal cord segmentation nn interpolation should be used.
            if [[ "${EXT}" == "${CORD_EXT}" ]]; then

                INTERP="nn"

            fi

            # Move all subject segmentations into the template space
            sct_merge_images \
                -i $(IFS=" " ; echo "${SUB_LIST_SEG[*]}") \
                -w $(IFS=" " ; echo "${SUB_LIST_WARP[*]}") \
                -d "${TEMPLATE}t2.nii.gz" \
                -o "${SUBJECT}${EXT}_template.nii.gz" \
                -x "${INTERP}"

            rm "src_0_template_partialVolume.nii.gz" "src_0_template.nii.gz" "src_0native_bin.nii.gz"

        done

        # Multiply the subject lesions mask by the subject cord mask in the template space
        sct_maths \
            -i "${SUB_LESIONS_SEG_TEMPLATE}" \
            -mul "${SUB_CORD_SEG_TEMPLATE}" \
            -o "${SUB_LESIONS_SEG_TEMPLATE}"

    else
        echo -e "Already done will not overwrite"
    fi

    # Add subject's cord and lesions segmentation in template space to the list

    LIST_CORD_SEG_TEMPLATE+=("$(realpath "${SUB_CORD_SEG_TEMPLATE}")")
    LIST_LESIONS_SEG_TEMPLATE+=("$(realpath "${SUB_LESIONS_SEG_TEMPLATE}")")

done

# Exit if no cord segmentation file found
if [[ ${#LIST_CORD_SEG_TEMPLATE[@]} < 1 ]]; then

    echo "No cord segmentation file found"
    exit 1

fi

# Exit if no lesion segmentation file found
if [[ ${#LIST_LESIONS_SEG_TEMPLATE[@]} < 1 ]]; then

    echo "No lesion segmentation file found"
    exit 1

fi

# Create LFM
# ----------------------------------------------------------------------------------------------------------------------

# Create temporary folder
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

echo -e "\nInitialise lesios and cord sum files"

CORD_SUM="seg_template_sum.nii.gz"
LESIONS_SUM="lesionseg_template_sum.nii.gz"

# Create an initial image with zeros.
sct_maths \
    -i "${TEMPLATE}cord.nii.gz" \
    -mul 0 \
    -o "${CORD_SUM}"

sct_maths \
    -i "${TEMPLATE}cord.nii.gz" \
    -mul 0 \
    -o "${LESIONS_SUM}"

echo -e "\nSum cord and lesions masks"

# Add all cord/lesions segmentations to the initial map.
sct_maths \
    -i "${CORD_SUM}" \
    -add $(IFS=" " ; echo "${LIST_CORD_SEG_TEMPLATE[*]}") \
    -o "${CORD_SUM}"

sct_maths \
    -i "${LESIONS_SUM}" \
    -add $(IFS=" " ; echo "${LIST_LESIONS_SEG_TEMPLATE[*]}") \
    -o "${LESIONS_SUM}"

echo -e "\nMake output file"

# Make the map with sum of all lesions divided by the sum of all cords.
sct_maths \
    -i "${LESIONS_SUM}" \
    -div "${CORD_SUM}" \
    -o "${OUT_FILE}"

if [[ ${MASK_TO_COVERAGE} == 1 ]]; then

    echo -e "\nMask the result to the parts of the spinal cord area covered by all subjects"

    COVERAGE_MASK="seg_template_coverage_mask.nii.gz"

    sct_maths \
        -i "${CORD_SUM}" \
        -thr ${#LIST_CORD_SEG_TEMPLATE[@]} \
        -o "${COVERAGE_MASK}"

    sct_maths \
        -i "${OUT_FILE}" \
        -mul "${COVERAGE_MASK}" \
        -o "${OUT_FILE}"

fi

echo -e "\nMask the result to the specific cord region"

REGION_MASK="seg_template_region_mask.nii.gz"

sct_maths \
    -i "${TEMPLATE}levels.nii.gz" \
    -thr ${LEVEL_MIN} -uthr ${LEVEL_MAX} \
    -o "${REGION_MASK}"

sct_maths -i "${REGION_MASK}" -bin 0 -o "${REGION_MASK}"

sct_maths \
    -i "${OUT_FILE}" \
    -mul "${REGION_MASK}" \
    -o "${OUT_FILE}"

# Remove temporary folder
rm -r "${TEMP_DIR}"
