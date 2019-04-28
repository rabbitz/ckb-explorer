class CreateBlocks < ActiveRecord::Migration[5.2]
  def change
    create_table :blocks do |t|
      t.string :difficulty, limit: 66
      t.binary :block_hash
      t.bigint :number
      t.binary :parent_hash
      t.jsonb :seal
      t.bigint :timestamp
      t.binary :transactions_root
      t.binary :proposals_root
      t.integer :uncles_count
      t.binary :uncles_hash
      t.binary :uncle_block_hashes
      t.integer :version
      t.binary :proposals
      t.integer :proposals_count
      t.decimal :cell_consumed, precision: 64, scale: 2
      t.binary :miner_hash
      t.integer :status, limit: 2
      t.decimal :reward, precision: 64, scale: 2
      t.decimal :total_transaction_fee, precision: 64, scale: 2
      t.bigint :ckb_transactions_count, default: 0
      t.decimal :total_cell_capacity, precision: 64, scale: 2
      t.binary :witnesses_root

      t.timestamps
    end
    add_index :blocks, :block_hash, unique: true
    add_index :blocks, [:block_hash, :status]
    add_index :blocks, [:number, :status]
  end
end
