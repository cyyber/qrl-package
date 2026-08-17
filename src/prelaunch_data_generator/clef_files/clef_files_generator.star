shared_utils = import_module("../../shared_utils/shared_utils.star")
clef_files_module = import_module("./clef_files.star")
constants = import_module("../../package_io/constants.star")

CLEF_KEYSTORE_OUTPUT_DIRPATH = "/clef-keystore/"

# Clef key is encrypted with a passphrase (>=10 characters)
CLEF_KEY_PASSWORD = constants.CLEF_PASSWORD
CLEF_KEY_PASSWORD_FILEPATH_ON_GENERATOR = "/tmp/clef-key-password.txt"
CLEF_KEY_SEED_FILEPATH_ON_GENERATOR = "/tmp/clef-key-seed.txt"

GQRL_TOOLS_IMAGE = "qrledger/go-qrl:alltools-stable"

SUCCESSFUL_EXEC_CMD_EXIT_CODE = 0

SERVICE_NAME_PREFIX = "clef-files-generation-"

ENTRYPOINT_ARGS = [
    "sleep",
    "99999",
]


# Launches a prelaunch data generator IMAGE, for use in various of the genesis generation
def launch_prelaunch_data_generator(
    plan,
    files_artifact_mountpoints,
    service_name_suffix,
    docker_cache_params,
):
    config = get_config(files_artifact_mountpoints, docker_cache_params)

    service_name = "{0}{1}".format(
        SERVICE_NAME_PREFIX,
        service_name_suffix,
    )
    plan.add_service(service_name, config)

    return service_name


def get_config(files_artifact_mountpoints, docker_cache_params):
    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            GQRL_TOOLS_IMAGE,
        ),
        entrypoint=ENTRYPOINT_ARGS,
        files=files_artifact_mountpoints,
    )


# Generates the clef files artifact: the keystore, and the auto-approval
# data when requested
def generate_clef_files(
    plan, prefunded_account, docker_cache_params, auto_approve=False
):
    service_name = launch_prelaunch_data_generator(
        plan, {}, "el-clef", docker_cache_params
    )

    # Clef key password file
    write_clef_key_password_file_cmd = [
        "sh",
        "-c",
        "echo '{0}' > {1}".format(
            CLEF_KEY_PASSWORD,
            CLEF_KEY_PASSWORD_FILEPATH_ON_GENERATOR,
        ),
    ]
    write_clef_key_password_file_cmd_result = plan.exec(
        service_name=service_name,
        description="Storing clef key password in a file",
        recipe=ExecRecipe(command=write_clef_key_password_file_cmd),
    )
    plan.verify(
        write_clef_key_password_file_cmd_result["code"],
        "==",
        SUCCESSFUL_EXEC_CMD_EXIT_CODE,
    )

    clef_key_password_artifact_name = plan.store_service_files(
        service_name, CLEF_KEY_PASSWORD_FILEPATH_ON_GENERATOR, name="clef-key-password"
    )

    # Clef key seed file
    write_clef_key_seed_file_cmd = [
        "sh",
        "-c",
        "echo '{0}' > {1}".format(
            prefunded_account.seed,
            CLEF_KEY_SEED_FILEPATH_ON_GENERATOR,
        ),
    ]
    write_clef_key_seed_file_cmd_result = plan.exec(
        service_name=service_name,
        description="Storing clef key seed in a file",
        recipe=ExecRecipe(command=write_clef_key_seed_file_cmd),
    )
    plan.verify(
        write_clef_key_seed_file_cmd_result["code"],
        "==",
        SUCCESSFUL_EXEC_CMD_EXIT_CODE,
    )

    clef_key_seed_artifact_name = plan.store_service_files(
        service_name, CLEF_KEY_SEED_FILEPATH_ON_GENERATOR, name="clef-key-seed"
    )

    output_dirpath = CLEF_KEYSTORE_OUTPUT_DIRPATH

    import_clef_key_cmd = '{0} --suppress-bootwarn --keystore={1} importraw --password={2} {3} '.format(
        "clef",
        shared_utils.path_join(output_dirpath, "keystore"),
        CLEF_KEY_PASSWORD_FILEPATH_ON_GENERATOR,
        CLEF_KEY_SEED_FILEPATH_ON_GENERATOR,
    )

    command_result = plan.exec(
        service_name=service_name,
        description="Generating keystore",
        recipe=ExecRecipe(command=["sh", "-c", import_clef_key_cmd]),
    )
    plan.verify(command_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

    if auto_approve:
        prepare_auto_approval(plan, service_name, prefunded_account, output_dirpath)

    # Store output into file artifact
    artifact_name = plan.store_service_files(
        service_name, output_dirpath, name="clef"
    )

    base_dirname_in_artifact = shared_utils.path_base(output_dirpath)
    clef_files = clef_files_module.new_clef_files(
         artifact_name,
        shared_utils.path_join(base_dirname_in_artifact, "keystore"),
        shared_utils.path_join(base_dirname_in_artifact, "configdir") if auto_approve else None,
        shared_utils.path_join(base_dirname_in_artifact, "rules.js") if auto_approve else None,
    )

    return clef_files


# Prepares everything clef needs to sign for the development account without
# human interaction: a master seed, an attested ruleset that approves requests
# for that account only, and the stored keystore credential. All interactive
# prompts happen here, at generation time, where a failure is loud.
def prepare_auto_approval(plan, service_name, prefunded_account, output_dirpath):
    configdir = shared_utils.path_join(output_dirpath, "configdir")
    rules_filepath = shared_utils.path_join(output_dirpath, "rules.js")

    rules_js = "\n".join(
        [
            "function ApproveTx(request) {",
            '    if (request.transaction.from.toLowerCase() == "%s") {'
            % prefunded_account.address.lower(),
            '        return "Approve"',
            "    }",
            '    return "Reject"',
            "}",
            "",
            'function ApproveSignData() { return "Approve" }',
            "",
            'function ApproveListing() { return "Approve" }',
            "",
            "// No-op lifecycle hooks; clef logs an error for undefined ones.",
            "function OnSignerStartup() {}",
            "",
            "function OnApprovedTx() {}",
        ]
    )

    setup_cmd = """set -e
printf '%s\\n%s\\n' '{password}' '{password}' | clef --configdir={configdir} --suppress-bootwarn init
cat > {rules_filepath} <<'RULES'
{rules_js}
RULES
printf '%s\\n' '{password}' | clef --configdir={configdir} --suppress-bootwarn attest $(sha256sum {rules_filepath} | cut -d ' ' -f 1)
printf '%s\\n%s\\n%s\\n' '{password}' '{password}' '{password}' | clef --configdir={configdir} --keystore={keystore_dirpath} --suppress-bootwarn setpw {address}
""".format(
        password=constants.CLEF_PASSWORD,
        configdir=configdir,
        rules_filepath=rules_filepath,
        rules_js=rules_js,
        keystore_dirpath=shared_utils.path_join(output_dirpath, "keystore"),
        address=prefunded_account.address,
    )

    command_result = plan.exec(
        service_name=service_name,
        description="Preparing clef auto-approval",
        recipe=ExecRecipe(command=["sh", "-c", setup_cmd]),
    )
    plan.verify(command_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)
