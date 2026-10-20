"""
this is s a really dumb script that sends tokens to the receiver from the sender every 3 seconds
this is being used as of 2023-09-06 to guarantee that payloads are delivered

This legacy helper uses upstream web3.py account signing, which derives and
validates 20-byte Ethereum addresses. It is intentionally disabled for QRL
64-byte addresses until it is ported to a QRL-aware signing stack.
"""
from functools import partial

import os
import time
import logging
import click


VALUE_TO_SEND = 0x9184

logging.basicConfig(filename="/tmp/sender.log",
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.DEBUG)

# this is the last prefunded address
SENDER = os.getenv("SENDER_PRIVATE_KEY", "17fdf89989597e8bcac6cdfcc001b6241c64cece2c358ffc818b72ca70f5e1ce")
# this is the first prefunded address
RECEIVER = os.getenv("RECEIVER_PUBLIC_KEY", "Qa73c065f7018cc0cfff98028d8ef1ff746f5cb425bc8840a4cdc2a6eb717faa121a2e959a6a0dac2d7c38252d70e4541397b0967880f00b9bd0c4c5d0fc46b2d")
EL_URI = os.getenv("EL_RPC_URI", 'http://0.0.0.0:53913')


def send_transaction():
    raise RuntimeError(
        "mev_custom_flood/sender.py is not QRL 64-byte address compatible: "
        "web3.py account signing derives 20-byte Ethereum addresses. Port this "
        "helper to a QRL-aware signer before using it."
    )

    # Setting w3 as constant causes recursion exceeded error after ~500 transactions
    # Thus it's created everytime a transaction is sent
    w3 = Web3(Web3.HTTPProvider(EL_URI))

    sender_account = w3.eth.account.from_key(SENDER)
    w3.middleware_onion.add(construct_sign_and_send_raw_middleware(sender_account))

    transaction = {
        "from": sender_account.address,
        "value": VALUE_TO_SEND,
        "to": RECEIVER,
        "data": "0xabcd",
        "gasPrice": w3.eth.gas_price,
    }

    estimated_gas = w3.eth.estimate_gas(transaction)

    transaction["gas"] = estimated_gas

    tx_hash = w3.eth.send_transaction(transaction)

    tx = w3.eth.get_transaction(tx_hash)
    logging.info(tx_hash.hex())
    assert tx["from"] == sender_account.address


def delayed_send(interval_between_transactions):
    send_transaction()
    time.sleep(interval_between_transactions)


@click.command()
@click.option('--interval_between_transactions', default=0.5, help='Interval between successive transaction sends (in seconds). The value may be an integer or decimal')
def run_infinitely(interval_between_transactions):
    raise RuntimeError(
        "mev_custom_flood/sender.py is disabled for QRL 64-byte addresses. "
        "Port it to a QRL-aware signer before using it."
    )

    logging.info(f"Using sender {SENDER} receiver {RECEIVER} and el_uri {EL_URI}")
    spam = send_transaction if interval_between_transactions == 0 else partial(delayed_send, interval_between_transactions)
    while True:
        try:
            spam()
        except Exception as e:
            print(e)
            print("restarting flood as previous one failed")


if __name__ == "__main__":
    run_infinitely()
