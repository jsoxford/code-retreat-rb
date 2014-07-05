class CodeRetreat
  def truthy
    true
  end

  def falsey
    true
  end
end

RSpec.describe CodeRetreat do
  it "#truthy is true" do
    cr = CodeRetreat.new
    expect(cr.truthy).to eq(true)
  end

  it "#falsey is false" do
    cr = CodeRetreat.new
    expect(cr.falsey).to eq(false)
  end
end
