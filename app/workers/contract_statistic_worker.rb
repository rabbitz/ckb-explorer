class ContractStatisticWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical"

  def perform
    h24_tx_ids = CkbTransaction.h24.pluck(:id)
    Contract.find_each do |contract|
      contract.update(
        ckb_transactions_count: contract.cell_dependencies.count,
        h24_ckb_transactions_count: contract.cell_dependencies.where(ckb_transaction_id: h24_tx_ids).count,
        deployed_cells_count: contract.deployed_cell_outputs&.live&.size,
        referring_cells_count: contract.referring_cell_outputs&.live&.size,
        total_deployed_cells_capacity: contract.deployed_cell_outputs&.live&.sum(:capacity),
        total_referring_cells_capacity: contract.referring_cell_outputs&.live&.sum(:capacity),
        addresses_count: contract.referring_cell_outputs&.live&.select(:address_id)&.distinct&.count,
      )
    end
  end
end
