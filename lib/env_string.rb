class EnvString
  def initialize(str)
    @str = str
  end

  def development?
    @str == 'development'
  end

  def test?
    @str == 'test'
  end

  def production?
    @str == 'production'
  end
end
