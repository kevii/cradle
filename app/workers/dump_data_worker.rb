class DumpDataWorker < Workling::Base
  def counting(options)
    number = options[:count]
    while(number < 100) do
      sleep(1)
      number = number + 1
      logger.info(number.to_s)
      Workling::Return::Store.set(options[:uid], number)
    end
  end
end