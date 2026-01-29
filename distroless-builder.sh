#!/bin/bash

# !! Testable block: argument handling

# -- Configuration loading --

# Array of configuration files
# The values defined in the latter overwrite the values in the previous config files
CONFIGURATION_FILES=( )

# Execute each pipeline in a container and not on the host system executing this script.
USE_CONTAINERS="yes"
# Docker compatible interface for managing containers (create, start, exec, stop, rm) and container images (build). Useful only if 'USE_CONTAINERS=yes'.
CONTAINER_MANAGEMENT_CLI="podman"

# Controls wether to pull or build image. Useful only if 'USE_CONTAINERS=yes'.
# Value 'pull': Download image instead of trying to build it.
# Value 'build': Builds image instead of trying to pull it.
# Value 'local': Assume that the image exists locally on the script host and use that without any attempt to build or pull it.
# Values: build|pull|local
WORKER_CONTAINER_IMAGE_SOURCE="build"
# variables related to building the work container. Useful only if 'WORKER_CONTAINER_IMAGE_SOURCE=build' and 'USE_CONTAINER=yes' are set.
WORKER_CONTAINER_IMAGE_BUILD_USE_BASE_IMAGE="docker.io/library/debian:12"
# Set this to a image name to use across all pipelines. The image needs to include all dependencies such as python3 to execute the scripts in each pipeline. Useful only if 'USE_CONTAINER=yes' is set.
WORKER_CONTAINER_IMAGE_NAME="localhost/distroless-builder"
# Set this to the images' tag name to use across all pipelines. The tag needs to include all dependencies such as python3 to execute the scripts in each pipeline. Useful only if 'USE_CONTAINER=yes' is set.
WORKER_CONTAINER_IMAGE_TAG="latest"

# Recreate container even if it already exists. Useful only if 'USE_CONTAINER=yes' is set.
# Values: yes|no
WORKER_CONTAINER_ALWAYS_RECREATE="no"
# Name of the worker container. This is where apache2 and its dependencies gets installed in to be able to collect it and its dependencies. Useful only if 'USE_CONTAINER=yes' is set.
WORKER_CONTAINER_NAME="distroless-builder"
# Path to directory where to find the resources needed to build the worker container. Useful only if 'WORKER_CONTAINER_IMAGE_SOURCE=build' and 'USE_CONTAINER=yes' are set.
# The directory must contain a 'Containerfile' and needs to be the container context at the same time. Used as building context if 'WORKER_CONTAINER_IMAGE_SOURCE=build' and 'USE_CONTAINER=yes' are set.
WORKER_CONTAINER_RESOURCE_PATH="worker_container"

# Stop but do not remove container at the end. Useful only if 'USE_CONTAINER=yes' is set.
# Values: yes|no
REMOVE_WORKER_CONTAINER_AT_END="yes"

# Name of package to install
# PACKAGE_INSTALL="apache2 libapache2-mod-fcgid php8.4 php8.4-fpm php8.4-cli"
PACKAGE_INSTALL=""
# List of application paths to collect
# The package management system installs the application and its dependencies into certain locations inside the container. We need to inform the collector to take a look on these locations in this space separated list: It copies them and collects sub dependencies.
# The collector currently does not support analyzing the packages the package management system downloads in order to find out the list of paths itself
# LIST_OF_APP_PATH="/usr/sbin/apache2 /etc/php /etc/apache2"
LIST_OF_APP_PATHS=""

# Destination folder in worker container where the collector shall save the app and its resources to inside the container for pickup by this script. Useful only if 'USE_CONTAINER=yes' is set.
DESTINATION_FOLDER_IN_WORKER_CONTAINER="/dest"
# Destination folder on script host where to copy the collected resources needed to run the app.
DESTINATION_FOLDER_ON_SCRIPT_HOST="distroless_files"

# Optional parameter. Array of idempotent custom commands to execute before the application resources including the dependencies will be collected. These commands are being executed in the working directory of the destination folder.
# If `USE_CONTAINER=yes` is set, then these commands are being executed in the container.
# If `USE_CONTAINER=no` is set, then these commands are being executed on the script host.
CUSTOM_COMMANDS_BEFORE_COLLECTION=()

# Optional parameter. Array of idempotent custom commands to execute after all application resources including dependencies have been collected. These commands are being executed in the working directory of the destination folder.
# If `USE_CONTAINER=yes` is set, then these commands are being executed in the container.
# If `USE_CONTAINER=no` is set, then these commands are being executed on the script host
CUSTOM_COMMANDS_AFTER_COLLECTION=()

# Can only be used from inside a configuration file: Path to the directory containing the currently loaded configuration file.
# DIRECTORY_OF_CONFIG_FILE

# Can only be used from inside a configuration file: Path to the configuration file from which the current configuration is being read.
# CONFIG_FILE_PATH

for i in "$@"; do
	case $i in
		--config-file=*)
			CONFIGURATION_FILES+=( "${i#*=}" )
			;;
		--configuration-file=*)
			CONFIGURATION_FILES+=( "${i#*=}" )
			;;
	esac
done

if [ "${#CONFIGURATION_FILES[@]}" -gt 0 ]; then
	for CONFIG_FILE_PATH in "${CONFIGURATION_FILES[@]}"; do
		if ! [ -f "${CONFIG_FILE_PATH}" ]; then
			printf "\033[1;31mERROR: Could not find configuration file '${CONFIG_FILE_PATH}'\033[0;m\n"
			exit 1
		fi
		printf "\033[0;33mSourcing configuration file '${CONFIG_FILE_PATH}'\033[0;m ...\n"
		DIRECTORY_OF_CONFIG_FILE=$(dirname "${CONFIG_FILE_PATH}")
		source "${CONFIG_FILE_PATH}"
		DIRECTORY_OF_CONFIG_FILE=""
	done
	printf "\033[0;33mConfiguration parameters defined on the command line still overwrite those with the same meaning in a configuration file.\033[0;m\n"
fi

for i in "$@"; do
	case $i in
		# check for this CLI argument at this stage of the script too to prevent the script to complain about
		# Unknown argument: `--configuration-file=[...]`
		# as this would confuse users and won't be true.
		--configuration-file=*)
			shift
			;;
		--config-file=*)
			shift
			;;
		--use-containers=*)
			USE_CONTAINERS="${i#*=}"
			shift
			;;
		--container-management-cli=*)
			CONTAINER_MANAGEMENT_CLI="${i#*=}"
			shift
			;;
		--worker-container-image-source=*)
			WORKER_CONTAINER_IMAGE_SOURCE="${i#*=}"
			shift
			;;
		--worker-container-image-build-use-base-image=*)
			WORKER_CONTAINER_IMAGE_BUILD_USE_BASE_IMAGE="${i#*=}"
			shift
			;;
		--worker-container-image-name=*)
			WORKER_CONTAINER_IMAGE_NAME="${i#*=}"
			shift
			;;
		--worker-container-image-tag=*)
			WORKER_CONTAINER_IMAGE_TAG="${i#*=}"
			shift
			;;
		--worker-container-always-recreate=*)
			WORKER_CONTAINER_ALWAYS_RECREATE="${i#*=}"
			shift
			;;
		--worker-container-name=*)
			WORKER_CONTAINER_NAME="${i#*=}"
			shift
			;;
		--worker-container-resource-path=*)
			WORKER_CONTAINER_RESOURCE_PATH="${i#*=}"
			shift
			;;
		--remove-worker-container-at-end=*)
			REMOVE_WORKER_CONTAINER_AT_END="${i#*=}"
			shift
			;;
		--package-install=*)
			PACKAGE_INSTALL="${i#*=}"
			shift
			;;
		--list-of-app-paths=*)
			LIST_OF_APP_PATHS="${i#*=}"
			shift
			;;
		--destination-folder-in-worker-container=*)
			DESTINATION_FOLDER_IN_WORKER_CONTAINER="${i#*=}"
			shift
			;;
		--destination-folder-on-script-host=*)
			DESTINATION_FOLDER_ON_SCRIPT_HOST="${i#*=}"
			shift
			;;
		*)
			printf "\033[0;31mUnknown argument: \`$i\`, ignoring it ...\033[0;m\n">&2
			shift
			;;
	esac
done

# !! Testable block: Functions

function usage() {
	printf "\033[0;31mInvalid or insufficient arguments provided!\n\033[0;m">&2
	printf "\033[1;37mUSAGE:\033[0;m $0 \033[0;33m--package-install=\033[0;m'>arguments to apt install>' \033[0;33m--list-of-app-paths=\033[0;m'<arguments to collector>'\n">&2
	exit 1
}

function clean_up() {
	if [ "${USE_CONTAINERS}" == "no" ]; then
		return 0
	fi

	printf "\033[0;34mStopping worker container ...\033[0;m\n"
	${CONTAINER_MANAGEMENT_CLI} stop "${WORKER_CONTAINER_NAME}"

	if [ "${REMOVE_WORKER_CONTAINER_AT_END}" == "yes" ]; then
		printf "\033[0;34mRemoving worker container ...\033[0;m\n"
		${CONTAINER_MANAGEMENT_CLI} rm "${WORKER_CONTAINER_NAME}"
	fi
}

function signal_handler() {
	printf "\033[1;31mHandling exit signal ...\033[0;m\n"
	clean_up
	exit 0

}

function die_or_continue() {
	local errorcode=$?
	if [ ${errorcode} -gt 0 ]; then
		printf "\033[1;31mERROR: An error occurred, stopping script ...\033[0;m\n"
		clean_up
		exit ${errorcode}
	fi

	return 0
}

function custom_command_execution() {
	CUSTOM_COMMANDS=( "$@" )
	
	if [ "${USE_CONTAINERS}" == "yes" ]; then
		${CONTAINER_MANAGEMENT_CLI} exec ${WORKER_CONTAINER_NAME} bash -c "if ! [ -d '${DESTINATION_FOLDER_IN_WORKER_CONTAINER}' ]; then mkdir -p '${DESTINATION_FOLDER_IN_WORKER_CONTAINER}'; fi"

		for i in "${CUSTOM_COMMANDS[@]}"; do
			printf "\033[0;33mExecuting \`\033[0;m${i}\033[0;m\`\033[0;33m ...\033[0;m\n"
			${CONTAINER_MANAGEMENT_CLI} exec -w ${DESTINATION_FOLDER_IN_WORKER_CONTAINER} ${WORKER_CONTAINER_NAME} bash -c "${i}"
			die_or_continue
		done
	elif [ "${USE_CONTAINERS}" == "no" ]; then
		if ! [ -d "${DESTINATION_FOLDER_ON_SCRIPT_HOST}" ]; then
			mkdir -p "${DESTINATION_FOLDER_ON_SCRIPT_HOST}"
		fi

		for i in "${CUSTOM_COMMANDS[@]}"; do
			printf "\033[0;33mExecuting \`\033[0;m${i}\033[0;m\`\033[0;33m ...\033[0;m\n"
			(
				cd ${DESTINATION_FOLDER_ON_SCRIPT_HOST}
				${i}
			)
			die_or_continue
		done
	fi
}

trap signal_handler SIGTERM SIGINT SIGABRT SIGHUP

# !! Testable block: Pipeline start

if [ "${USE_CONTAINERS}" == "yes" ]; then
	printf "\033[1;34mStep: Prepare & Start pipeline.\033[0;m\n"

	if [ "${WORKER_CONTAINER_IMAGE_SOURCE}" == "pull" ]; then
		${CONTAINER_MANAGEMENT_CLI} pull "${WORKER_CONTAINER_IMAGE_NAME}:${WORKER_CONTAINER_IMAGE_TAG}"
	fi

	image_exists=$(${CONTAINER_MANAGEMENT_CLI} image ls --format '{{.Repository}}:{{.Tag}}' | grep "${WORKER_CONTAINER_IMAGE_NAME}:${WORKER_CONTAINER_IMAGE_TAG}")
	container_exists=$(${CONTAINER_MANAGEMENT_CLI} ps --all --format '{{.Names}}' | grep ${WORKER_CONTAINER_NAME})

	if [ "${WORKER_CONTAINER_IMAGE_SOURCE}" == "pull" ] && [ -z "${image_exists}" ]; then
		printf "\033[1;31mERROR: An error occurred while pulling image, stopping script ...\033[0;m\n"
		exit 1
	fi

	if [ "${WORKER_CONTAINER_IMAGE_SOURCE}" == "pull" ]; then
		printf "\033[0;34mUsing the locally stored image '${WORKER_CONTAINER_IMAGE_NAME}' to create worker container.\033[0;m\n"
	fi

	if [ "${WORKER_CONTAINER_IMAGE_SOURCE}" == "build" ]; then
		printf "\033[0;34mBuilding container image for worker container ...\033[0;m\n"
		current_image_digest=$(${CONTAINER_MANAGEMENT_CLI} build --quiet --tag "${WORKER_CONTAINER_IMAGE_NAME}:${WORKER_CONTAINER_IMAGE_TAG}" --file "${WORKER_CONTAINER_RESOURCE_PATH}/Containerfile" --build-arg "BASE_IMAGE=${WORKER_CONTAINER_IMAGE_BUILD_USE_BASE_IMAGE}" "${WORKER_CONTAINER_RESOURCE_PATH}")

		if [ -n "${container_exists}" ] && [ "${WORKER_CONTAINER_ALWAYS_RECREATE}" == "no" ]; then
			container_built_with_image_digest=$(podman container inspect "${WORKER_CONTAINER_NAME}" | jq -cr '.[0].Image')
			if [ "${current_image_digest}" == "${container_built_with_image_digest}" ]; then
				printf "\033[1;33mExplanation:\033[0;33m The container with name '${WORKER_CONTAINER_NAME}' is not going to be recreated as a container with that name exists already and is not outdated."
			else
					printf "\033[1;33mExplanation:\033[0;33m The container with name '${WORKER_CONTAINER_NAME}' is going to be recreated as its outdated due to an image update."
				WORKER_CONTAINER_ALWAYS_RECREATE="yes"
			fi
			printf " Set 'WORKER_CONTAINER_ALWAYS_RECREATE' to 'yes' to always force container recreation even when the container is up to date.\033[0;m\n"
		fi
	fi

	if [ -z "${container_exists}" ]; then
		printf "\033[0;34mContainer '${WORKER_CONTAINER_NAME}' does not exist. It is going to be created.\033[0;m\n"
	fi

	if [ -z "${container_exists}" ] || [ "${WORKER_CONTAINER_ALWAYS_RECREATE}" == "yes" ]; then
		printf "\033[0;34mCreating worker container ...\033[0;m\n"
		${CONTAINER_MANAGEMENT_CLI} create --replace --tty --name "${WORKER_CONTAINER_NAME}" "${WORKER_CONTAINER_IMAGE_NAME}:${WORKER_CONTAINER_IMAGE_TAG}"
	fi

	printf "\033[0;34mStarting worker container ...\033[0;m\n"
	${CONTAINER_MANAGEMENT_CLI} start "${WORKER_CONTAINER_NAME}"
	die_or_continue
fi

# !! Testable block: Custom command execution before collect step

if [ -n "${#CUSTOM_COMMANDS_BEFORE_COLLECTION[@]}" ] && [ "${#CUSTOM_COMMANDS_BEFORE_COLLECTION[@]}" -gt 0 ]; then
		printf "\033[1;34mStep: Execute custom commands before the collect step.\033[0;m\n"
		custom_command_execution "${CUSTOM_COMMANDS_BEFORE_COLLECTION[@]}"
fi


# !! Testable block: Collect step

printf "\033[1;34mStep: Collect application and its dependencies.\033[0;m\n"
if [ "${USE_CONTAINERS}" == "yes" ]; then
	${CONTAINER_MANAGEMENT_CLI} exec "${WORKER_CONTAINER_NAME}" ./start-collecting --package-install="${PACKAGE_INSTALL}" --destination-folder="${DESTINATION_FOLDER_IN_WORKER_CONTAINER}" --list-of-app-paths="${LIST_OF_APP_PATHS}"
	die_or_continue
else
	(
	cd ${WORKER_CONTAINER_RESOURCE_PATH}/tools
	start-collecting --package-install="${PACKAGE_INSTALL}" --destination-folder="${DESTINATION_FOLDER_ON_SCRIPT_HOST}" --list-of-app-paths="${LIST_OF_APP_PATHS}"
	)
	die_or_continue
fi

# !! Testable block: Custom command execution after collect step

if [ -n "${#CUSTOM_COMMANDS_AFTER_COLLECTION[@]}" ] && [ "${#CUSTOM_COMMANDS_AFTER_COLLECTION[@]}" -gt 0 ]; then
		printf "\033[1;34mStep: Execute custom commands after the collect step.\033[0;m\n"
		custom_command_execution "${CUSTOM_COMMANDS_AFTER_COLLECTION[@]}"
fi

# !! Testable block: Tear down

if [ "${USE_CONTAINERS}" == "yes" ]; then
	printf "\033[1;34mStep: Save results.\033[0;m\n"
	if ! [ -d "${DESTINATION_FOLDER_ON_SCRIPT_HOST}" ]; then
		printf "\033[0;34mCreating destination folder on script host ...\033[0;m\n"
		mkdir -p "${DESTINATION_FOLDER_ON_SCRIPT_HOST}"
	fi
	printf "\033[0;34mSaving results ...\033[0;m\n"
	${CONTAINER_MANAGEMENT_CLI} cp "${WORKER_CONTAINER_NAME}:${DESTINATION_FOLDER_IN_WORKER_CONTAINER}/." "${DESTINATION_FOLDER_ON_SCRIPT_HOST}"
	die_or_continue
fi

printf "\033[1;34mStep: Stop and remove worker container.\033[0;m\n"
clean_up

# !! Non Testable block: Do not test

printf "\033[0;32mResults are in '${DESTINATION_FOLDER_ON_SCRIPT_HOST}' and include everything needed to run the application inside a distroless container ...\033[0;m\n"

exit 0