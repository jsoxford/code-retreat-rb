Code Retreat Game of Life runner
================================

This client will watch your code for changes and print test results to the terminal. When your tests fail the details will also be printed.

## Setup

- Install with `gem install coderetreat`
- Run your code using `cr your_code.rb` (mac users will need to restart their terminal)


## Example

Here's an example you can use to get started:

```ruby
class CodeRetreat

  # the cell always dies, more like the game of death!
  def self.tickCell(cell)
    return false
  end

  # a rather patronising method!
  def self.truth
    true
  end

  # this one doesn't even work
  def self.falsehood
    true
  end
end

RSpec.describe CodeRetreat do
  it "#truth is true" do
    expect(CodeRetreat.truth).to eq(true)
  end

  it "#falsehood is false" do
    expect(CodeRetreat.falsehood).to eq(false)
  end
end
```


## Notes

- To be evaluated your code must include a CodeRetreat class.
- The CodeRetreat class should have a static method called tickCell, which takes the data for a cell and returns if it should be alive in the next tick (as a boolean)
