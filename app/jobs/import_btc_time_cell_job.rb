class ImportBtcTimeCellJob < ApplicationJob
  queue_as :bitcoin

  def perform(cell_id)
    ApplicationRecord.transaction do
      cell_output = CellOutput.find_by(id: cell_id)
      return unless cell_output

      lock_script = cell_output.lock_script
      return unless CkbUtils.is_btc_time_lock_cell?(lock_script)

      parsed_args = CkbUtils.parse_btc_time_lock_cell(lock_script.args)
      txid = parsed_args.txid
      Rails.logger.info("Importing btc time cell #{cell_id} txid #{txid}")

      # build bitcoin transaction
      raw_tx = fetch_raw_transaction(txid)
      return unless raw_tx

      tx = build_transaction!(raw_tx, cell_output.ckb_transaction)
      # build transfer
      BitcoinTransfer.create_with(
        bitcoin_transaction_id: tx.id,
        ckb_transaction_id: cell_output.ckb_transaction_id,
        lock_type: "btc_time",
      ).find_or_create_by!(
        cell_output_id: cell_id,
      )
    end
  end

  def build_transaction!(raw_tx, ckb_tx)
    tx = BitcoinTransaction.find_by(txid: raw_tx["txid"])
    return tx if tx

    created_at = Time.at((ckb_tx.block_timestamp / 1000).to_i).in_time_zone
    BitcoinTransaction.create!(
      txid: raw_tx["txid"],
      tx_hash: raw_tx["hash"],
      time: raw_tx["time"],
      block_hash: raw_tx["blockhash"],
      block_height: 0,
      created_at:,
    )
  end

  def fetch_raw_transaction(txid)
    data = Rails.cache.read(txid)
    data ||= rpc.getrawtransaction(txid, 2)
    Rails.cache.write(txid, data, expires_in: 10.minutes) unless Rails.cache.exist?(txid)
    data["result"]
  rescue StandardError => e
    Rails.logger.error "get bitcoin raw transaction #{txid} failed: #{e}"
    nil
  end

  def rpc
    @rpc ||= Bitcoin::Rpc.instance
  end
end
