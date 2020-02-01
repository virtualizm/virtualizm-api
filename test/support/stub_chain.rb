# frozen_string_literal: true

class StubChain
  def initialize
    @stubs = []
  end

  def add_stub(object, meth, val_or_callable, *block_args)
    @stubs.push(object: object, args: [meth, val_or_callable, *block_args])
  end

  def use_stubs(&block)
    cyclic_use_stub(&block)
  end

  private

  def cyclic_use_stub(&block)
    stub_args = @stubs.shift
    if stub_args
      stub_args[:object].stub(*stub_args[:args]) { use_stubs(&block) }
    else
      block.call
    end
  end
end
