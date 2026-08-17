def new_clef_files(
    file_artifact_uuid,
    keystore_relative_dirpath,
    configdir_relative_dirpath=None,
    rules_relative_filepath=None,
):
    return struct(
        file_artifact_uuid=file_artifact_uuid,
        # ------------ All paths below are relative to the root of the files artifact ----------------
        keystore_relative_dirpath=keystore_relative_dirpath,
        # Set only when auto-approval was prepared for the network.
        configdir_relative_dirpath=configdir_relative_dirpath,
        rules_relative_filepath=rules_relative_filepath,
    )
