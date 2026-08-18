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


# Generates the clef files artifact: the keystore for every managed account,
# and the auto-approval data when requested
def generate_clef_files(
    plan, prefunded_accounts, docker_cache_params, auto_approve=False
):
    service_name = launch_prelaunch_data_generator(
        plan, {}, "el-clef", docker_cache_params
    )

    output_dirpath = CLEF_KEYSTORE_OUTPUT_DIRPATH
    keystore_dirpath = shared_utils.path_join(output_dirpath, "keystore")

    import_commands = [
        "set -e",
        "echo '{0}' > {1}".format(
            CLEF_KEY_PASSWORD, CLEF_KEY_PASSWORD_FILEPATH_ON_GENERATOR
        ),
    ]
    for account in prefunded_accounts:
        import_commands.append(
            "echo '{0}' > {1}".format(
                account.seed, CLEF_KEY_SEED_FILEPATH_ON_GENERATOR
            )
        )
        import_commands.append(
            "clef --suppress-bootwarn --keystore={0} importraw --password={1} {2}".format(
                keystore_dirpath,
                CLEF_KEY_PASSWORD_FILEPATH_ON_GENERATOR,
                CLEF_KEY_SEED_FILEPATH_ON_GENERATOR,
            )
        )

    command_result = plan.exec(
        service_name=service_name,
        description="Generating keystore",
        recipe=ExecRecipe(command=["sh", "-c", "\n".join(import_commands)]),
    )
    plan.verify(command_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

    if auto_approve:
        prepare_auto_approval(plan, service_name, prefunded_accounts, output_dirpath)

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


# Prepares everything clef needs to sign for the development accounts without
# human interaction: a master seed, an attested ruleset that approves requests
# for those accounts only, and the stored keystore credentials. All interactive
# prompts happen here, at generation time, where a failure is loud.
def prepare_auto_approval(plan, service_name, prefunded_accounts, output_dirpath):
    configdir = shared_utils.path_join(output_dirpath, "configdir")
    rules_filepath = shared_utils.path_join(output_dirpath, "rules.js")

    rules_js = "\n".join(
        ["var approvedSenders = ["]
        + [
            '    "{0}",'.format(account.address.lower())
            for account in prefunded_accounts
        ]
        + [
            "];",
            "",
            "function ApproveTx(request) {",
            "    if (approvedSenders.indexOf(request.transaction.from.toLowerCase()) >= 0) {",
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
for address in {addresses}; do
	printf '%s\\n%s\\n%s\\n' '{password}' '{password}' '{password}' | clef --configdir={configdir} --keystore={keystore_dirpath} --suppress-bootwarn setpw "$address"
done
""".format(
        password=constants.CLEF_PASSWORD,
        configdir=configdir,
        rules_filepath=rules_filepath,
        rules_js=rules_js,
        keystore_dirpath=shared_utils.path_join(output_dirpath, "keystore"),
        addresses=" ".join([account.address for account in prefunded_accounts]),
    )

    command_result = plan.exec(
        service_name=service_name,
        description="Preparing clef auto-approval",
        recipe=ExecRecipe(command=["sh", "-c", setup_cmd]),
    )
    plan.verify(command_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)
