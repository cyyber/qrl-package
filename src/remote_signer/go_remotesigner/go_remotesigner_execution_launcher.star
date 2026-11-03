constants = import_module("../../package_io/constants.star")
genesis_constants = import_module(
    "../../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)
go_remotesigner = import_module("./go_remotesigner_launcher.star")
input_parser = import_module("../../package_io/input_parser.star")
node_metrics = import_module("../../node_metrics_info.star")
remote_signer_context = import_module("../remote_signer_context.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")

# go-remotesigner's execution mode holds development accounts in front of one
# execution client's JSON-RPC: it lists the accounts, signs messages and
# transactions with them, sends transactions through the client, and forwards
# the methods its allowlist allows to the client. Only the image's full
# flavour, remotesigner, has the execution command.

# The prefunded development accounts it holds. The package's other users of
# the prefunded accounts sign for none of them: clef holds 12 to 21, the MEV
# flood 6 and 7, the custom flood the last one.
GO_REMOTESIGNER_EXECUTION_ACCOUNTS = genesis_constants.PRE_FUNDED_ACCOUNTS[8:12]

# The signer's files, at constants.REMOTE_SIGNER_MOUNTPOINT_ON_CLIENTS, besides
# the sign token (constants.REMOTE_SIGNER_AUTH_TOKEN_FILENAME), the CA that
# issued its certificate (constants.REMOTE_SIGNER_TLS_CA_FILENAME) and the TLS
# files the consensus signer has too
GO_REMOTESIGNER_EXECUTION_KEY_CONFIGS_DIRNAME = "keys"
GO_REMOTESIGNER_EXECUTION_POLICY_FILENAME = "policy.yaml"
# The client's files: the token, the CA and the accounts' addresses, in lower
# case, one per line
GO_REMOTESIGNER_EXECUTION_ACCOUNTS_FILENAME = "accounts.txt"

# The audit log, in the image's data directory
GO_REMOTESIGNER_EXECUTION_AUDIT_LOG_FILEPATH = shared_utils.path_join(
    go_remotesigner.GO_REMOTESIGNER_DATA_DIRPATH, "audit.jsonl"
)

# Where the step that prepares the files mounts the rendered configs
CONFIGS_MOUNTPOINT_ON_FILES_STEP = "/configs"

# The signer reads one key-config document per account: the account's
# 51-byte extended seed
KEY_CONFIG_TEMPLATE = """type: file-raw
keyType: ML_DSA_87
privateKey: "0x{{ .Seed }}"
"""

# A listener beyond loopback needs a policy file. This one lets every account
# sign what it could sign without one: any transaction, contract creations
# included, whose fee (gas x maxFeePerGas) is at most the signer's default cap
# of 1 quanta.
POLICY = """default:
  contract-creation: true
"""


def launch(
    plan,
    launcher,
    service_name,
    image,
    participant,
    global_log_level,
    tolerations,
    node_selectors,
    port_publisher,
    remote_signer_index,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.el_log_level, global_log_level, go_remotesigner.VERBOSITY_LEVELS
    )

    signer_files_artifact_uuid, client_files_artifact_uuid = prepare_files(
        plan, launcher, service_name
    )

    config = get_config(
        launcher=launcher,
        participant=participant,
        image=image,
        service_name=service_name,
        signer_files_artifact_uuid=signer_files_artifact_uuid,
        log_level=log_level,
        tolerations=tolerations,
        node_selectors=node_selectors,
        port_publisher=port_publisher,
        remote_signer_index=remote_signer_index,
    )

    remote_signer_service = plan.add_service(service_name, config)

    remote_signer_http_url = "https://{0}:{1}".format(
        service_name, go_remotesigner.GO_REMOTESIGNER_HTTP_PORT_NUM
    )
    wait_for_accounts(
        plan,
        launcher,
        service_name,
        remote_signer_http_url,
        client_files_artifact_uuid,
    )

    remote_signer_metrics_port = remote_signer_service.ports[
        go_remotesigner.GO_REMOTESIGNER_METRICS_PORT_ID
    ]
    metrics_url = "{0}:{1}".format(
        remote_signer_service.ip_address, remote_signer_metrics_port.number
    )
    remote_signer_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, go_remotesigner.METRICS_PATH, metrics_url
    )

    return remote_signer_context.new_remote_signer_context(
        http_url=remote_signer_http_url,
        client_name=constants.REMOTE_SIGNER_TYPE.go_remotesigner_execution,
        service_name=service_name,
        metrics_info=remote_signer_node_metrics_info,
    )


# Prepares two files artifacts with the generator image (sh, openssl):
# - the signer's: a key-config file per account and the policy file, the sign
#   token, a TLS certificate and key for the service name, and the CA that
#   issued them, owned by the image's user, the secrets 0600;
# - a client's: the same token and CA, and the accounts' addresses.
# The seeds and the token never appear in a command line, and the CA key never
# leaves this step.
def prepare_files(plan, launcher, service_name):
    templates = {
        GO_REMOTESIGNER_EXECUTION_POLICY_FILENAME: shared_utils.new_template_and_data(
            POLICY, {}
        ),
        GO_REMOTESIGNER_EXECUTION_ACCOUNTS_FILENAME: shared_utils.new_template_and_data(
            "".join(
                sorted(
                    [
                        account.address.lower() + "\n"
                        for account in GO_REMOTESIGNER_EXECUTION_ACCOUNTS
                    ]
                )
            ),
            {},
        ),
    }
    for index, account in enumerate(GO_REMOTESIGNER_EXECUTION_ACCOUNTS):
        templates[
            shared_utils.path_join(
                GO_REMOTESIGNER_EXECUTION_KEY_CONFIGS_DIRNAME,
                "account-{0}.yaml".format(index),
            )
        ] = shared_utils.new_template_and_data(
            KEY_CONFIG_TEMPLATE, {"Seed": account.seed}
        )
    configs_artifact_uuid = plan.render_templates(
        templates, "{0}-configs".format(service_name)
    )

    signer = "/out/signer"
    client = "/out/client"
    signer_key_configs = shared_utils.path_join(
        signer, GO_REMOTESIGNER_EXECUTION_KEY_CONFIGS_DIRNAME
    )
    signer_token = shared_utils.path_join(
        signer, constants.REMOTE_SIGNER_AUTH_TOKEN_FILENAME
    )
    signer_ca = shared_utils.path_join(signer, constants.REMOTE_SIGNER_TLS_CA_FILENAME)
    signer_cert = shared_utils.path_join(
        signer, go_remotesigner.GO_REMOTESIGNER_TLS_CERT_FILEPATH
    )
    signer_key = shared_utils.path_join(
        signer, go_remotesigner.GO_REMOTESIGNER_TLS_KEY_FILEPATH
    )
    client_token = shared_utils.path_join(
        client, constants.REMOTE_SIGNER_AUTH_TOKEN_FILENAME
    )
    client_ca = shared_utils.path_join(client, constants.REMOTE_SIGNER_TLS_CA_FILENAME)

    run = "\n".join(
        [
            "set -eu",
            "mkdir -p {0} {1} {2}".format(
                signer_key_configs, shared_utils.path_dir(signer_cert), client
            ),
            "cp {0}/{1}/*.yaml {2}/".format(
                CONFIGS_MOUNTPOINT_ON_FILES_STEP,
                GO_REMOTESIGNER_EXECUTION_KEY_CONFIGS_DIRNAME,
                signer_key_configs,
            ),
            "cp {0}/{1} {2}/".format(
                CONFIGS_MOUNTPOINT_ON_FILES_STEP,
                GO_REMOTESIGNER_EXECUTION_POLICY_FILENAME,
                signer,
            ),
            "cp {0}/{1} {2}/".format(
                CONFIGS_MOUNTPOINT_ON_FILES_STEP,
                GO_REMOTESIGNER_EXECUTION_ACCOUNTS_FILENAME,
                client,
            ),
            'test "$(ls {0} | wc -l)" -eq {1}'.format(
                signer_key_configs, len(GO_REMOTESIGNER_EXECUTION_ACCOUNTS)
            ),
            "printf '0x%s\\n' \"$(openssl rand -hex 32)\" > {0}".format(signer_token),
            "cp {0} {1}".format(signer_token, client_token),
        ]
        + go_remotesigner.tls_commands(service_name, client_ca, signer_cert, signer_key)
        + [
            "cp {0} {1}".format(client_ca, signer_ca),
            "chown -R {0} {1}".format(go_remotesigner.GO_REMOTESIGNER_USER, signer),
            "chmod 0700 {0} {1} {2}".format(
                signer, signer_key_configs, shared_utils.path_dir(signer_cert)
            ),
            "chmod 0600 {0} {1}/* {2} {3} {4}".format(
                signer_token,
                signer_key_configs,
                signer_cert,
                signer_key,
                client_token,
            ),
        ]
    )

    result = plan.run_sh(
        name="{0}-files".format(service_name),
        description="Preparing the account keys, sign token and TLS files of {0}".format(
            service_name
        ),
        image=launcher.generator_image,
        files={CONFIGS_MOUNTPOINT_ON_FILES_STEP: configs_artifact_uuid},
        run=run,
        store=[
            StoreSpec(src=signer + "/", name="{0}-files".format(service_name)),
            StoreSpec(src=client + "/", name="{0}-client-files".format(service_name)),
        ],
    )

    return result.files_artifacts[0], result.files_artifacts[1]


# As for the consensus signer, a client with the client's files checks the
# TLS-only API: /upcheck answers 200 once the accounts are loaded, publicKeys
# must then list exactly the accounts, and qrl_chainId, which the signer
# forwards, must answer with the network's chain ID, from the execution client
def wait_for_accounts(
    plan, launcher, service_name, http_url, client_files_artifact_uuid
):
    mountpoint = constants.REMOTE_SIGNER_MOUNTPOINT_ON_CLIENTS
    ca = shared_utils.path_join(mountpoint, constants.REMOTE_SIGNER_TLS_CA_FILENAME)
    token = shared_utils.path_join(
        mountpoint, constants.REMOTE_SIGNER_AUTH_TOKEN_FILENAME
    )
    accounts = shared_utils.path_join(
        mountpoint, GO_REMOTESIGNER_EXECUTION_ACCOUNTS_FILENAME
    )
    timeout = go_remotesigner.GO_REMOTESIGNER_READY_TIMEOUT_SECONDS
    authorization = '-H "Authorization: Bearer $(cat {0})"'.format(token)

    run = "\n".join(
        [
            "set -eu",
            "deadline=$(($(date +%s) + {0}))".format(timeout),
            "until curl -fs -o /dev/null --max-time 5 --cacert {0} {1}/upcheck; do".format(
                ca, http_url
            ),
            '  if [ "$(date +%s)" -ge "$deadline" ]; then',
            "    echo '{0} did not load its accounts within {1}s' >&2; exit 1".format(
                service_name, timeout
            ),
            "  fi",
            "  sleep 1",
            "done",
            "curl -fsS --max-time 60 --cacert {0} {1} {2}/api/v1/execution/publicKeys | jq -r '.[].address | ascii_downcase' | LC_ALL=C sort > /tmp/served-accounts.txt".format(
                ca, authorization, http_url
            ),
            "if ! cmp -s /tmp/served-accounts.txt {0}; then".format(accounts),
            '  echo "{0} serves $(wc -l < /tmp/served-accounts.txt) accounts, not the $(wc -l < {1}) it was given" >&2; exit 1'.format(
                service_name, accounts
            ),
            "fi",
            'chain_id=$(curl -fsS --max-time 60 --cacert {0} {1} -H \'Content-Type: application/json\' -d \'{{"jsonrpc":"2.0","id":1,"method":"qrl_chainId","params":[]}}\' {2}/ | jq -r .result)'.format(
                ca, authorization, http_url
            ),
            'if [ "$chain_id" != "$(printf \'0x%x\' {0})" ]; then'.format(
                launcher.network_id
            ),
            '  echo "{0} reaches an execution client whose chain ID is $chain_id, not {1}" >&2; exit 1'.format(
                service_name, launcher.network_id
            ),
            "fi",
        ]
    )

    plan.run_sh(
        name="{0}-ready".format(service_name),
        description="Waiting for {0} to load its accounts".format(service_name),
        image=launcher.generator_image,
        files={mountpoint: client_files_artifact_uuid},
        run=run,
        wait="{0}s".format(timeout + 60),
    )


def get_config(
    launcher,
    participant,
    image,
    service_name,
    signer_files_artifact_uuid,
    log_level,
    tolerations,
    node_selectors,
    port_publisher,
    remote_signer_index,
):
    mountpoint = constants.REMOTE_SIGNER_MOUNTPOINT_ON_CLIENTS
    # Global flags, then the execution command and its flags. The image's
    # entrypoint sets some of these global flags already; the last value wins.
    cmd = [
        "--data-path=" + go_remotesigner.GO_REMOTESIGNER_DATA_DIRPATH,
        "--http-listen-host=0.0.0.0",
        "--http-listen-port={0}".format(go_remotesigner.GO_REMOTESIGNER_HTTP_PORT_NUM),
        # The names clients connect with: clients in the enclave dial the
        # service name, clients on the host the published port
        "--http-host-allowlist={0},localhost,127.0.0.1".format(service_name),
        "--http-auth-token-file="
        + shared_utils.path_join(
            mountpoint, constants.REMOTE_SIGNER_AUTH_TOKEN_FILENAME
        ),
        "--tls-cert-file="
        + shared_utils.path_join(
            mountpoint, go_remotesigner.GO_REMOTESIGNER_TLS_CERT_FILEPATH
        ),
        "--tls-key-file="
        + shared_utils.path_join(
            mountpoint, go_remotesigner.GO_REMOTESIGNER_TLS_KEY_FILEPATH
        ),
        "--key-config-path="
        + shared_utils.path_join(
            mountpoint, GO_REMOTESIGNER_EXECUTION_KEY_CONFIGS_DIRNAME
        ),
        "--metrics-enabled=true",
        # Prometheus scrapes the service by its IP address
        "--metrics-host-allowlist=*",
        "--metrics-host=0.0.0.0",
        "--metrics-port={0}".format(go_remotesigner.GO_REMOTESIGNER_METRICS_PORT_NUM),
        "--logging=" + log_level,
        "execution",
        "--chain-id={0}".format(launcher.network_id),
        "--downstream-http-host=" + launcher.el_context.ip_addr,
        "--downstream-http-port={0}".format(launcher.el_context.rpc_port_num),
        "--execution-policy-file="
        + shared_utils.path_join(mountpoint, GO_REMOTESIGNER_EXECUTION_POLICY_FILENAME),
        "--execution-audit-log-file=" + GO_REMOTESIGNER_EXECUTION_AUDIT_LOG_FILEPATH,
    ]

    if len(participant.remote_signer_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.remote_signer_extra_params])

    ports = {}
    ports.update(go_remotesigner.GO_REMOTESIGNER_USED_PORTS)

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": go_remotesigner.get_public_ports(
            port_publisher, remote_signer_index
        ),
        "cmd": cmd,
        "files": {mountpoint: signer_files_artifact_uuid},
        "env_vars": participant.remote_signer_extra_env_vars,
        "labels": shared_utils.label_maker(
            client=constants.REMOTE_SIGNER_TYPE.go_remotesigner_execution,
            client_type=constants.CLIENT_TYPES.remote_signer,
            image=image[-constants.MAX_LABEL_LENGTH :],
            connected_client=launcher.el_context.client_name,
            extra_labels=participant.remote_signer_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.remote_signer_min_cpu > 0:
        config_args["min_cpu"] = participant.remote_signer_min_cpu
    if participant.remote_signer_max_cpu > 0:
        config_args["max_cpu"] = participant.remote_signer_max_cpu
    if participant.remote_signer_min_mem > 0:
        config_args["min_memory"] = participant.remote_signer_min_mem
    if participant.remote_signer_max_mem > 0:
        config_args["max_memory"] = participant.remote_signer_max_mem

    return ServiceConfig(**config_args)


def new_go_remotesigner_execution_launcher(el_context, network_id, generator_image):
    return struct(
        # The execution client whose JSON-RPC the signer fronts
        el_context=el_context,
        network_id=network_id,
        # Has sh, openssl, jq and curl: prepares the files and checks readiness
        generator_image=generator_image,
    )
