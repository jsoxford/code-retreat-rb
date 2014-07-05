class CodeRetreat

  def self.tickCell(cell)
    return false
  end

  def self.tickBoard(board)
    return board
  end

  def self.truthy
    true
  end

  def self.falsey
    false
  end
end

RSpec.describe CodeRetreat do
  it "#truthy is true" do
    expect(CodeRetreat.truthy).to eq(true)
  end

  it "#falsey is false" do
    expect(CodeRetreat.falsey).to eq(false)
  end
end
