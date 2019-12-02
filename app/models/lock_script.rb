class LockScript < ApplicationRecord
  belongs_to :address

  validates_presence_of :code_hash

  attribute :code_hash, :ckb_hash

  def cell_output
    CellOutput.find(cell_output_id)
  end

  def to_node_lock
    {
      args: args,
      code_hash: code_hash,
      hash_type: hash_type
    }
  end

  def lock_info
    bin_args = CKB::Utils.hex_to_bin(args)
    if code_hash == ENV["SECP_MULTISIG_CELL_TYPE_HASH"] && bin_args.bytesize == 28
      since = CKB::Utils.bin_to_hex(bin_args[-8..-1]).delete_prefix("0x")
      begin
        since_value = SinceParser.new(since).parse
        if since_value.present?
          tip_epoch = CkbUtils.parse_epoch(CkbSync::Api.instance.get_tip_header.epoch)
          genesis_block = Block.find_by(number: 0)
          genesis_block_time = DateTime.strptime(genesis_block.timestamp.to_s, "%Q")
          estimated_unlock_time = genesis_block_time + (since_value.number * 4 + since_value.index * 4 / since_value.length).hours

          { status: lock_info_status(since_value, tip_epoch), epoch_number: since_value.number.to_s, epoch_index: since_value.index.to_s, estimated_unlock_time: estimated_unlock_time.strftime("%Q") }
        end
      ensure SinceParser::IncorrectSinceFlagsError
        nil
      end
    end
  end

  private

  def lock_info_status(since_value, tip_epoch)
    after_lock_epoch_number = tip_epoch.number > since_value.number
    at_lock_epoch_number_but_exceeded_index = (tip_epoch.number == since_value.number &&
      tip_epoch.index * since_value.length > since_value.index * tip_epoch.length)

    after_lock_epoch_number || at_lock_epoch_number_but_exceeded_index ? "unlocked" : "locked"
  end
end

# == Schema Information
#
# Table name: lock_scripts
#
#  id             :bigint           not null, primary key
#  args           :string
#  code_hash      :binary
#  cell_output_id :bigint
#  address_id     :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hash_type      :string
#
# Indexes
#
#  index_lock_scripts_on_address_id      (address_id)
#  index_lock_scripts_on_cell_output_id  (cell_output_id)
#
