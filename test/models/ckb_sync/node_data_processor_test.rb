require "test_helper"

module CkbSync
  class NodeDataProcessorTest < ActiveSupport::TestCase
    test "#process_block should create one block" do
      assert_difference -> { Block.count }, 1 do
        VCR.use_cassette("blocks/10") do
          node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created block's attribute value should equal with the node block's attribute value" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        local_block = node_data_processor.process_block(node_block)

        node_block = node_block.to_h.deep_stringify_keys
        formatted_node_block = format_node_block(node_block)
        epoch_info = CkbUtils.get_epoch_info(formatted_node_block["epoch"])
        formatted_node_block["start_number"] = epoch_info.start_number
        formatted_node_block["length"] = epoch_info.length

        local_block_hash = local_block.attributes.select { |attribute| attribute.in?(%w(difficulty block_hash number parent_hash seal timestamp transactions_root proposals_hash uncles_count uncles_hash version proposals witnesses_root epoch start_number length dao)) }
        local_block_hash["hash"] = local_block_hash.delete("block_hash")
        local_block_hash["number"] = local_block_hash["number"].to_s
        local_block_hash["version"] = local_block_hash["version"].to_s
        local_block_hash["uncles_count"] = local_block_hash["uncles_count"].to_s
        local_block_hash["epoch"] = local_block_hash["epoch"].to_s
        local_block_hash["timestamp"] = local_block_hash["timestamp"].to_s

        assert_equal formatted_node_block.sort, local_block_hash.sort
      end
    end

    test "#process_block created block's proposals_count should equal with the node block's proposals size" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)

        local_block = node_data_processor.process_block(node_block)

        assert_equal node_block.proposals.size, local_block.proposals_count
      end
    end

    test "#process_block should generate miner's address when cellbase has witnesses" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/11") do
        node_block = CkbSync::Api.instance.get_block("0xd895e3fd670fd499567ce219cf8a8e6da27a91e1679ed01088fdcd1b072d3c4c")
        local_block = node_data_processor.process_block(node_block)
        expected_miner_hash = CkbUtils.miner_hash(node_block.transactions.first)
        expected_miner_address = Address.find_by(address_hash: expected_miner_hash)

        assert expected_miner_hash, local_block.miner_hash
        assert expected_miner_address, local_block.miner_address
      end
    end

    test "#process_block should generate miner's lock when cellbase has witnesses" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/11") do
        node_block = CkbSync::Api.instance.get_block("0xd895e3fd670fd499567ce219cf8a8e6da27a91e1679ed01088fdcd1b072d3c4c")
        expected_miner_lock_hash = CkbUtils.miner_lock_hash(node_block.transactions.first)
        block = node_data_processor.process_block(node_block)

        assert_equal expected_miner_lock_hash, block.miner_lock_hash
      end
    end

    test "#process_block generated block's total_cell_capacity should equal to the sum of transactions output capacity" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)

        local_block = node_data_processor.process_block(node_block)
        expected_total_capacity = CkbUtils.total_cell_capacity(node_block.transactions)

        assert_equal expected_total_capacity, local_block.total_cell_capacity
      end
    end

    test "#process_block generated block should has correct reward" do
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)

        local_block = node_data_processor.process_block(node_block)

        assert_equal CkbUtils.base_reward(node_block.header.number, node_block.header.epoch).to_i, local_block.reward
      end
    end

    test "#process_block generated block should has correct cell consumed" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)

        local_block = node_data_processor.process_block(node_block)

        assert_equal CkbUtils.block_cell_consumed(node_block.transactions), local_block.cell_consumed
      end
    end

    test "#process_block should create uncle_blocks" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_uncle_blocks = node_block.uncles

        assert_difference -> { UncleBlock.count }, node_block_uncle_blocks.size do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created uncle_block's attribute value should equal with the node uncle_block's attribute value" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_uncle_blocks = node_block.uncles.map { |uncle| uncle.to_h.deep_stringify_keys }
        formatted_node_uncle_blocks = node_uncle_blocks.map { |uncle_block| format_node_block(uncle_block).sort }

        local_block = node_data_processor.process_block(node_block)
        local_uncle_blocks =
          local_block.uncle_blocks.map do |uncle_block|
            uncle_block =
              uncle_block.attributes.select do |attribute|
                attribute.in?(%w(difficulty block_hash number parent_hash seal timestamp transactions_root proposals_hash uncles_count uncles_hash version proposals witnesses_root epoch dao))
              end
            uncle_block["hash"] = uncle_block.delete("block_hash")
            uncle_block["epoch"] = uncle_block["epoch"].to_s
            uncle_block["number"] = uncle_block["number"].to_s
            uncle_block["timestamp"] = uncle_block["timestamp"].to_s
            uncle_block["version"] = uncle_block["version"].to_s
            uncle_block["uncles_count"] = uncle_block["uncles_count"].to_s
            uncle_block.sort
          end

        assert_equal formatted_node_uncle_blocks.sort, local_uncle_blocks.sort
      end
    end

    test "#process_block created unlce_block's proposals_count should equal with the node uncle_block's proposals size" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_uncle_blocks = node_block.uncles
        node_uncle_blocks_count = node_uncle_blocks.reduce(0) { |memo, uncle_block| memo + uncle_block.proposals.size }

        local_block = node_data_processor.process_block(node_block)
        local_uncle_blocks = local_block.uncle_blocks
        local_uncle_blocks_count = local_uncle_blocks.reduce(0) { |memo, uncle_block| memo + uncle_block.proposals_count }

        assert_equal node_uncle_blocks_count, local_uncle_blocks_count
      end
    end

    test "#process_block should create ckb_transactions" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_transactions = node_block.transactions

        assert_difference -> { CkbTransaction.count }, node_block_transactions.count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created block's ckb_transactions_count should equal to transactions count" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)

        local_block = node_data_processor.process_block(node_block)

        assert_equal node_block.transactions.size, local_block.ckb_transactions_count
      end
    end

    test "#process_block created ckb_transaction's attribute value should equal with the node commit_transaction's attribute value" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_transactions = node_block.transactions
        formatted_node_block_transactions = node_block_transactions.map { |commit_transaction| format_node_block_commit_transaction(commit_transaction).sort }

        local_block = node_data_processor.process_block(node_block)
        local_ckb_transactions =
          local_block.ckb_transactions.map do |ckb_transaction|
            ckb_transaction = ckb_transaction.attributes.select { |attribute| attribute.in?(%w(tx_hash deps version witnesses)) }
            ckb_transaction["hash"] = ckb_transaction.delete("tx_hash")
            ckb_transaction["version"] = ckb_transaction["version"].to_s
            ckb_transaction.sort
          end

        assert_equal formatted_node_block_transactions, local_ckb_transactions
      end
    end

    test "#process_block should create cell_inputs" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_transactions = node_block.transactions
        node_cell_inputs_count = node_block_transactions.reduce(0) { |memo, commit_transaction| memo + commit_transaction.inputs.size }

        assert_difference -> { CellInput.count }, node_cell_inputs_count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test ".save_block created cell_inputs's attribute value should equal with the node cell_inputs's attribute value" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_transactions = node_block.transactions.map(&:to_h).map(&:deep_stringify_keys)
        node_block_cell_inputs = node_transactions.map { |commit_transaction| commit_transaction["inputs"].map(&:sort) }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_cell_inputs = local_block_transactions.map { |commit_transaction| commit_transaction.cell_inputs.map { |cell_input| cell_input.attributes.select { |attribute| attribute.in?(%(previous_output since)) }.sort } }.flatten

        assert_equal node_block_cell_inputs, local_block_cell_inputs
      end
    end

    test "#process_block should create cell_outputs" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_transactions = node_block.transactions
        node_cell_outputs_count = node_block_transactions.reduce(0) { |memo, commit_transaction| memo + commit_transaction.outputs.size }

        assert_difference -> { CellOutput.count }, node_cell_outputs_count do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created cell_outputs's attribute value should equal with the node cell_outputs's attribute value" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_transactions = node_block.transactions
        node_block_cell_outputs = node_block_transactions.map { |commit_transaction| commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output| format_node_block_cell_output(output).sort } }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_cell_outputs = local_block_transactions.map { |commit_transaction|
          commit_transaction.cell_outputs.map do |cell_output|
            attributes = cell_output.attributes
            attributes["capacity"] = attributes["capacity"].to_i.to_s
            attributes.select { |attribute| attribute.in?(%w(capacity data)) }.sort
          end
        }.flatten

        assert_equal node_block_cell_outputs, local_block_cell_outputs
      end
    end

    test "#process_block should create addresses for cell_output" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        locks = node_block.transactions.map(&:outputs).flatten.map(&:lock)
        local_block = node_data_processor.process_block(node_block)
        expected_lock_address = locks.map { |lock| Address.find_or_create_address(lock) }

        assert_equal expected_lock_address, local_block.cell_outputs.map(&:address)
      end
    end

    test "#process_block should create addresses for ckb transaction" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        locks = node_block.transactions.map(&:outputs).flatten.map(&:lock)
        local_block = node_data_processor.process_block(node_block)
        expected_lock_address = locks.map { |lock| Address.find_or_create_address(lock) }

        assert_equal expected_lock_address, local_block.ckb_transactions.map(&:addresses).flatten
      end
    end

    test "#process_block should create lock_scripts for output" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        expected_lock_scripts = node_block.transactions.map(&:outputs).flatten.map(&:lock).map(&:to_h)
        local_block = node_data_processor.process_block(node_block)
        actual_lock_scripts = local_block.cell_outputs.map { |cell_output| CKB::Types::Script.new(code_hash: cell_output.lock_script.code_hash, args: cell_output.lock_script.args) }.map(&:to_h)

        assert_equal expected_lock_scripts, actual_lock_scripts
      end
    end

    test "#process_block created lock_script's attribute value should equal with the node lock_script's attribute value" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_transactions = node_block.transactions
        node_block_lock_scripts = node_block_transactions.map { |commit_transaction| commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output| output["lock"] }.sort }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_lock_scripts = local_block_transactions.map { |commit_transaction| commit_transaction.cell_outputs.map { |cell_output| cell_output.lock_script.attributes.select { |attribute| attribute.in?(%w(args code_hash hash_type)) } }.sort }.flatten

        assert_equal node_block_lock_scripts, local_block_lock_scripts
      end
    end

    test "#process_block should create type_scripts" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        node_block_transactions = node_block.transactions
        node_cell_outputs = node_block_transactions.map { |commit_transaction| commit_transaction.outputs }.flatten
        node_cell_outputs_with_type_script = node_cell_outputs.select { |cell_output| cell_output.type.present? }

        assert_difference -> { TypeScript.count }, node_cell_outputs_with_type_script.size do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block created type_script's attribute value should equal with the node type_script's attribute value" do
      VCR.use_cassette("blocks/10") do
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        fake_node_block_with_type_script(node_block)
        node_block_transactions = node_block.transactions
        node_block_type_scripts = node_block_transactions.map { |commit_transaction| commit_transaction.to_h.deep_stringify_keys["outputs"].map { |output| output["type"] }.sort }.flatten

        local_block = node_data_processor.process_block(node_block)
        local_block_transactions = local_block.ckb_transactions
        local_block_type_scripts = local_block_transactions.map { |commit_transaction| commit_transaction.cell_outputs.map { |cell_output| cell_output.type_script.attributes.select { |attribute| attribute.in?(%w(args code_hash hash_type)) } }.sort }.flatten

        assert_equal node_block_type_scripts, local_block_type_scripts
      end
    end

    test "#process_block should update block's total transaction fee" do
      node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
      VCR.use_cassette("blocks/10") do
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
        local_block = node_data_processor.process_block(node_block)

        assert_equal 10**8 * 3, local_block.reload.total_transaction_fee
      end
    end

    test "#process_block should update cell status" do
      VCR.use_cassette("blocks/10") do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)

        assert_difference -> { CellOutput.dead.count }, 2 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "#process_block should fill all cell input's previous cell output id without cellbase's cell input" do
      VCR.use_cassette("blocks/10") do
        node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
        block = create(:block, :with_block_hash)
        ckb_transaction1 = create(:ckb_transaction, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        ckb_transaction2 = create(:ckb_transaction, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
        create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1, tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction2, block: block)
        create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 0, tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", generated_by: ckb_transaction1, block: block)
        local_block = node_data_processor.process_block(node_block)

        assert_empty local_block.cell_inputs.where(from_cell_base: false, previous_cell_output_id: nil)
      end
    end

    test "#process_block should update current block's miner address pending reward blocks count" do
      prepare_inauthentic_node_data(11)
      VCR.use_cassette("blocks/12") do
        node_block = CkbSync::Api.instance.get_block("0x4f1d958f0601d04d1bd88634fac4bcd65ffc8a42e8b0c50d065e70ba5e922840")
        cellbase = node_block.transactions.first
        lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
        miner_address = Address.find_or_create_address(lock_script)

        assert_difference -> { miner_address.reload.pending_reward_blocks_count }, 1 do
          node_data_processor.process_block(node_block)
        end
      end
    end

    test "cellbase's display inputs should contain target block number" do
      prepare_inauthentic_node_data(11)
      CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
        CKB::Types::BlockReward.new(
          total: "100000000000",
          primary: "100000000000",
          secondary: "0",
          tx_fee: "0",
          proposal_reward: "0"
        )
      )
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("blocks/12") do
        assert_difference "Block.count", 1 do
          node_block = CkbSync::Api.instance.get_block("0x4f1d958f0601d04d1bd88634fac4bcd65ffc8a42e8b0c50d065e70ba5e922840")
          node_data_processor.process_block(node_block)
          block = Block.last
          cellbase = Cellbase.new(block)
          expected_cellbase_display_inputs = [{ id: nil, from_cellbase: true, capacity: nil, address_hash: nil, target_block_number: cellbase.target_block_number }]

          assert_equal expected_cellbase_display_inputs, block.cellbase.display_inputs
        end
      end
    end

    test ".save_block generated transactions should has correct display output" do
      VCR.use_cassette("blocks/10") do
        CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
          CKB::Types::BlockReward.new(
            total: "100000000000",
            primary: "100000000000",
            secondary: "0",
            tx_fee: "0",
            proposal_reward: "0"
          )
        )
        node_block = CkbSync::Api.instance.get_block(DEFAULT_NODE_BLOCK_HASH)
        local_block = node_data_processor.process_block(node_block)

        local_ckb_transactions = local_block.ckb_transactions
        local_block_cell_outputs = local_ckb_transactions.map(&:display_outputs).flatten
        output = local_ckb_transactions.first.outputs.order(:id).first
        cellbase = Cellbase.new(local_block)
        expected_display_outputs = [{ id: output.id, capacity: output.capacity, address_hash: output.address_hash, target_block_number: cellbase.target_block_number, block_reward: cellbase.block_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward }]

        assert_equal expected_display_outputs, local_block_cell_outputs
      end
    end

    test "genesis block's cellbase display outputs should have multiple cells" do
      CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
        CKB::Types::BlockReward.new(
          total: "100000000000",
          primary: "100000000000",
          secondary: "0",
          tx_fee: "0",
          proposal_reward: "0"
        )
      )
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      VCR.use_cassette("genesis_block") do
        node_block = CkbSync::Api.instance.get_block_by_number(0)
        node_data_processor.process_block(node_block)

        block = Block.last
        cellbase = Cellbase.new(block)
        expected_cellbase_display_outputs = block.cellbase.cell_outputs.map { |cell_output| { id: cell_output.id, capacity: cell_output.capacity, address_hash: cell_output.address_hash, target_block_number: cellbase.target_block_number, block_reward: cellbase.block_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward } }

        assert_equal expected_cellbase_display_outputs, block.cellbase.display_outputs
      end
    end

    test "cellbase's display outputs should contain block reward commit reward, proposal reward and secondary reward" do
      prepare_inauthentic_node_data(11)
      CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
        CKB::Types::Epoch.new(
          epoch_reward: "250000000000",
          difficulty: "0x1000",
          length: "2000",
          number: "0",
          start_number: "0"
        )
      )
      CkbSync::Api.any_instance.stubs(:get_cellbase_output_capacity_details).returns(
        CKB::Types::BlockReward.new(
          total: "100000000000",
          primary: "100000000000",
          secondary: "0",
          tx_fee: "0",
          proposal_reward: "0"
        )
      )
      VCR.use_cassette("blocks/12") do
        assert_difference "Block.count", 1 do
          node_block = CkbSync::Api.instance.get_block("0x4f1d958f0601d04d1bd88634fac4bcd65ffc8a42e8b0c50d065e70ba5e922840")
          node_data_processor.process_block(node_block)

          block = Block.last
          cellbase = Cellbase.new(block)
          cell_output = block.cellbase.cell_outputs.first
          expected_cellbase_display_outputs = [{ id: cell_output.id, capacity: cell_output.capacity, address_hash: cell_output.address_hash, target_block_number: cellbase.target_block_number, block_reward: cellbase.block_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward }]

          assert_equal expected_cellbase_display_outputs, block.cellbase.display_outputs
        end
      end
    end

    test "should change the existing block status to abandoned when it is invalid" do
      prepare_inauthentic_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      VCR.use_cassette("blocks/10") do
        node_data_processor.call

        assert_equal "abandoned", local_block.reload.status
      end
    end

    test "should delete all uncle blocks under the existing block when it is invalid" do
      prepare_inauthentic_node_data(HAS_UNCLES_BLOCK_NUMBER)
      local_block = Block.find_by(number: HAS_UNCLES_BLOCK_NUMBER)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.uncle_blocks

      VCR.use_cassette("blocks/#{HAS_UNCLES_BLOCK_NUMBER}") do
        assert_changes -> { local_block.reload.uncle_blocks.count }, from: local_block.uncle_blocks.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all ckb transactions under the existing block when it is invalid" do
      prepare_inauthentic_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.ckb_transactions

      VCR.use_cassette("blocks/10") do
        assert_changes -> { local_block.reload.ckb_transactions.count }, from: local_block.ckb_transactions.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all cell inputs under the existing block when it is invalid" do
      prepare_inauthentic_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.cell_inputs

      VCR.use_cassette("blocks/10") do
        assert_changes -> { local_block.reload.cell_inputs.count }, from: local_block.cell_inputs.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all cell outputs under the existing block when it is invalid" do
      prepare_inauthentic_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")

      assert_not_empty local_block.cell_outputs

      VCR.use_cassette("blocks/10") do
        assert_changes -> { local_block.reload.cell_outputs.count }, from: local_block.cell_outputs.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all lock script under the existing block when it is invalid" do
      prepare_inauthentic_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      origin_lock_scripts = local_block.cell_outputs.map(&:lock_script)

      assert_not_empty origin_lock_scripts

      VCR.use_cassette("blocks/10") do
        assert_changes -> { local_block.reload.cell_outputs.map(&:lock_script).count }, from: origin_lock_scripts.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should delete all type script under the existing block when it is invalid" do
      prepare_inauthentic_node_data(9)
      local_block = Block.find_by(number: 9)
      local_block.update(block_hash: "0x419c632366c8eb9635acbb39ea085f7552ae62e1fdd480893375334a0f37d1bx")
      origin_type_scripts = local_block.cell_outputs.map(&:type_script)

      assert_not_empty origin_type_scripts

      VCR.use_cassette("blocks/10") do
        assert_changes -> { local_block.reload.cell_outputs.map(&:type_script).count }, from: origin_type_scripts.count, to: 0 do
          node_data_processor.call
        end
      end
    end

    test "should do nothing when target block is not exist" do
      prepare_inauthentic_node_data
      local_block = Block.find_by(number: 10)
      local_block.update(number: 100_000_000)

      VCR.use_cassette("blocks/10", :record => :new_episodes) do
        assert_nil node_data_processor.call
      end
    end

    private

    def node_data_processor
      CkbSync::NodeDataProcessor.new
    end
  end
end
