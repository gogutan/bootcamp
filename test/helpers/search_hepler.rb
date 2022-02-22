# frozen_string_literal: true

require 'test_helper'

class  SearchHelperTest < ActionView::TestCase
  test 'does it return correct boolean value in talk' do
    user = users(:kimura)
    assert_equal true, talk?(user)
  end
end
