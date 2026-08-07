def new_prefunded_account(address, seed):
    return struct(address=address, seed=seed)


# Pre-funded devnet accounts: fresh ML-DSA-87 keypairs generated with
# @theqrl/wallet.js v3 (SHAKE-256 address derivation).
#
#   address - 64-byte QRL address (Q + 128 hex chars)
#   seed    - 51-byte ExtendedSeed (descriptor || ML-DSA-87 seed), hex-encoded;
#             feed to wallet.js / web3.qrl seedToAccount()
#
# Dev-only keys, publicly known — never fund them on a real network.
PRE_FUNDED_ACCOUNTS = [
    # account #0
    new_prefunded_account(
        "Q0838a121a6e4dd8a51e7437b152fabbc76a173f077132f2c2ed021c7b0991e70da4dba44e9ec00984a90f28dfb0aabbda1ddc9e98a76ab0acb6644c5e76fbbe8",
        "0100002fbf2a7d031dbd37936d694d25e3e9be2e25b5270e5753f8b09ae189fd8a8d5de868c8cfc49683476eccc0d5a8aeaf4b",
    ),
    # account #1
    new_prefunded_account(
        "Qa73c065f7018cc0cfff98028d8ef1ff746f5cb425bc8840a4cdc2a6eb717faa121a2e959a6a0dac2d7c38252d70e4541397b0967880f00b9bd0c4c5d0fc46b2d",
        "0100002fa45cae7e96414b644715d0e29de4ca12864fe7d52f3260545ad7c280bd7ceee79627d99d3bf9a1bbb2bcd73d5be401",
    ),
    # account #2
    new_prefunded_account(
        "Q9e6c9f4c6c1ce6db822f2ddcf5410d6e42167107051562ce5a50ee4aa72194202c235e9fa51cc51ebf82344c17c630631f2e9880e036b8ed07a659a61d5250bc",
        "010000ddd8d36ee38da727f968d103252e87e383089e3f10104e5fb2131003d85823b6302210f476b2dc8ec8262ee72a7efbdb",
    ),
    # account #3
    new_prefunded_account(
        "Q8f4908e3c4a2cfb256b4817d5f11556f2d00a1b266c173ef2c245f55229dc3cb3637749f02dae6a22fce513867ee4295b8513eac006568ddd0ff25a4955cdbcd",
        "0100006490ee184acab81627936c65ee08065d7dfc1b1d9d728664465153a788ec550bd7a7956c04c32e3f81ceda03abb04bb0",
    ),
    # account #4
    new_prefunded_account(
        "Qcd8411cb1b705905152fb5125df18dfc5a6c8570536a4e00c90619d51e6a57eabcf61957873305ed029c574f956f97518b9135b8b0582481898b06e7ccf19bf4",
        "01000089234246bb13fc275aa913812e0e9f1148e15d13ba952f4f96b71a588133bb879e0bce90228147791a685781c718a961",
    ),
    # account #5
    new_prefunded_account(
        "Q6527061dd3b71a740466121d9a59a86c669b8343c171302c56fcd44e0d1ff19288de99707dcbd240b6d95b1111a5f02616d2f693f99456a3d9fca37fb5ff22c8",
        "0100003ae18f4b5559e48f284f30b40656812b9d566c49eead223c38de2b3a81647a463d2b75fed7a2a09d11fe150df199c646",
    ),
    # account #6
    new_prefunded_account(
        "Qc2b3a47a15486d58ed6b109fd23cb0da1b39b417089aa9970991264c36ace50fac16adcfef434047ce2c1bf93f7c6e2313d3acf74d656499dbe9bb69a2e13070",
        "010000bc0b2df0e4e9c4665f834d364568dd0311fa72f3e2fb5238ec977eb45bf0d2a19fa02cb3023808881a2c88f98e5a6aaa",
    ),
    # account #7
    new_prefunded_account(
        "Qccfd5e90c61b84406dba1a6ad70a82a8ea9272154e16726d450feedb85e52a18cfd8c0d0a0d8d8f5f26dde33caae053b776397b5f043105562c5d41bf0b7fdb6",
        "010000ddeb0d748fc455526bc5db974c147e20a87a3f637c61d8563c78b209a647f5fd3abff02b0ad4c75ef5af347c747eceab",
    ),
    # account #8
    new_prefunded_account(
        "Q592126d9959af41646cafe4b650f56beb5b4b745c56f2668b37895a22c11f7ac3bc4ae5314d67268e9ee16a34f620f4d977adeba9dac46cda171d88cda0a80f2",
        "01000024cd5ca2b5baaa25cb51dc01fd55d6323f3f7b3b91dd716762ccc37698098d307b7cea67e8e2136ba18d078fc50a2520",
    ),
    # account #9
    new_prefunded_account(
        "Qf7871e62d1c1e0cd7ec1e301f28cbe996cb7efc867ceba488425489cb645f162acbd12d3d5fc6bfabef436e7ca98f7083e9245b53174a5242af21059cdf33b0f",
        "0100007f4f67e5d17fbcdf76cf2a4f5fe94fa3c5ae0c6a9794a5cfc579605b81ea931cbe41ff3d957fe40cab9e4ec2c4272c3b",
    ),
    # account #10
    new_prefunded_account(
        "Q599f661827bd3172b693771cbb47740aba38d9cba2e319c65175830231e73006073de1e991bf2f69de50ab2fb542b65bc2c319d661d5b1d81ad1a8b11f9947b7",
        "0100004ad81172162e4e5c030004cc288e759ef4ca58b564996bf8c93cabd551dba01bb339bae66fddc672bc6bd4555e5cfe0c",
    ),
    # account #11
    new_prefunded_account(
        "Q5e66fbec660e4d578c092640c410b7fd97b664064bd3cbcf0dcc1edc52d90060fefe7707b5d3cb5878ec27751433523c4752bab5bae0c885d066097d9033f7f8",
        "010000590da7a63776374f0ed49d0f49103953cccc49fb6e17f809eeb888e7a95266650bccfc8a7722da4ed297811fde271a48",
    ),
    # account #12
    new_prefunded_account(
        "Qd46ecb92367831f40ff99ec89a9bcd7ad4e6ca275cdad3f68506fffc201addd7f16bfcaad7bb8e4146babc1bdf470f77bf45eaefa978a5548191c753eac08093",
        "010000dda70db707efc9453b8e04980056f7d7b8158827488a6bd8f5a89fcab5cf5dd1c0918eaf51840d108dc101e0f3ddb89d",
    ),
    # account #13
    new_prefunded_account(
        "Qa1df778fcae99cac2b5b53eb4f0012c32b914d96a88b557b79816e5cafdab5f21ae5e98060fc0dfa543f1680ac358d98f30b924be9a15aada6d2c1ad65377199",
        "0100008ed11c54ebd033797c42c8efb3e582ecb1e03fbf5bc616c751cf175986334dc12a52268f25a8f3ae79c99662daf6ce47",
    ),
    # account #14
    new_prefunded_account(
        "Q738a3bdbcd5e0924d4923ebedfc378dd9111c977bb36116394e900761c741636cb1b9eff5fba549af1f624fed38d628aa1cc1d8f158def9e58eae84d3645a7a7",
        "010000d06550d47ce0840a61e7e58e86be8f4bbba4c0ebb64234ed61a0ead7d7969008afac84bb6582b611aaf69415e82fe49d",
    ),
    # account #15
    new_prefunded_account(
        "Qaa486a473fe6fde2cb98c7b436c2a09c4f0e9e800ec1861c2ec04299d84387af4f5046e3c540d60b6d75715071c4018b298e971481c7bf4a9a8b3212ac548502",
        "010000a1a0ddeeb25f251c1fe74f6dbf1cf5bda94f00785b4b05106a14dfaa2c1db7defedfc9ecdc34bc11ace5e8bcd4d42000",
    ),
    # account #16
    new_prefunded_account(
        "Q9e520861a3ce015b79fe2e2e894fce913b4313e018257ed5089e075adb6c248bad306c57c0e502d669fe3a08ff7dc258cb3cfca625c365c4bad33eab3ddd348d",
        "0100009de9896522d6b25840cd3e8d25ddb42fcb90c2e05243829cdb1653d2907f369b9956748c5bf261a37c77d1d347cd02ef",
    ),
    # account #17
    new_prefunded_account(
        "Q5dac13e0bbe17834eb3f02f6fef9c77b4b455196abc6e5f4dde37c08cab0d85842897ccd9110066fbe472043b5a28ec048ed350e13309d5daacca493d8b80739",
        "01000099689222155f6c98b8e5d0b03f05410e0e7f35543cebd68f4f6d732e366c48347a3789dcd701aa7b92a40b05319a5a0c",
    ),
    # account #18
    new_prefunded_account(
        "Q4155e8bdfa19ec3ebb36e889b0422aef1c339ba909d1138ab67ab4b97244c12e71bcb7ded8d1ec7a6969f23db04e47dc9404e2b7e4b0ce3c0329e790bc0b0325",
        "0100006b8d6445e39d5a143cbb723b8c65198a14232c2355e314b55a40cf70ccbe42cc13c0db17ceafa3e6637eaeebe801bff1",
    ),
    # account #19
    new_prefunded_account(
        "Q57feeb5132cefcd23facb1ee7e13fe687999c307ad8dd345e8e864df781c571cbfdf09a2e422f943017111c43648de6de50b628378732b5860ba817cdc8323fd",
        "0100005a4cd32b8d2fb85d776d16f0bc62b6f2e7d93b97646c39023ab36fa0d1f0862670ac8a35b5dff35ac942cff993c1e510",
    ),
    # account #20
    new_prefunded_account(
        "Q1a486f8261c071f56848015d51d4c9640015a33974dfd3c1b2f1cb53c01b53a300f8c750d2447bf58b96f7987d13b2ba707c90aad83ffc8f72b7a7e7aa1209da",
        "010000890a0508a3dce3193987b46d1cbc1103524da9e412f754f7e1e0b91a216abe35a57b51c1b983ffa7633c66e317a81cb4",
    ),
    # account #21
    new_prefunded_account(
        "Qffb51bb94ee8ebcaa574ca34f11a61c7f67c385c4c382808d1f609b4c27e38b4c1c3ded0af8d4fc807fcb75a54924f53868684132e6cf9765ea5d4055ec4b5f4",
        "01000077dbc5a8c6e52c5c9573daae746935bfd4b65c37861f0af15a0712e3f130960cd7ced4dffdf6a83520d18b065d7fc098",
    ),
]
