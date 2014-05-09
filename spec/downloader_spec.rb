require 'downloader'

describe Downloader, '#initialize' do

    it 'should fail with bad api-key' do
        expect { Downloader.new('abcdefghijklmnopqrstuvwxyz') }.to raise_error
        expect { Downloader.new(nil) }.to raise_error
        expect { Downloader.new('') }.to raise_error
        expect { Downloader.new('0123456789abcdefg0123456789abcdefg1234567') }.to raise_error
    end

    it 'should fail with no args' do
        expect { Downloader.new }.to raise_error
    end

    it 'should be fine with valid hex api-key' do
        Downloader.new('0123456789abcdefg0123456789abcdefg123456')
    end
end