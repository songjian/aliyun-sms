require "aliyun/sms/version"
require "openssl"
require "base64"
require "typhoeus"
require "erb"
include ERB::Util

module Aliyun
  module Sms
    class Configuration
      attr_accessor :access_key_secret, :access_key_id, :action, :format, :region_id,
                    :sign_name, :signature_method, :signature_version, :sms_version
      def initialize
        @access_key_secret = ''
        @access_key_id = ''
        @action = ''
        @format = ''
        @region_id = ''
        @sign_name = ''
        @signature_method = ''
        @signature_version = ''
        @sms_version = ''
      end
    end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def create_params(mobile_num, template_code, message_param)
        sms_params ={
          'AccessKeyId' => configuration.access_key_id,
          'Action' => configuration.action,
          'Format' => configuration.format,
          # 'ParamString' => message_param,
          # 'RecNum' => mobile_num,
          'PhoneNumbers' => mobile_num,
          'RegionId' => configuration.region_id,
          'SignName' => configuration.sign_name,
          'SignatureMethod' => configuration.signature_method,
          'SignatureNonce' => seed_signature_nonce,
          'SignatureVersion' => configuration.signature_version,
          'TemplateCode' => template_code,
          'Timestamp' => seed_timestamp,
          'Version' => configuration.sms_version,
          'TemplateParam' => message_param,
        }
      end

      # Signature=zJDF%2BLrzhj%2FThnlvIToysFRq6t4%3D&
      # AccessKeyId=testId
      # &Action=SendSms
      # &Format=XML
      # &OutId=123
      # &PhoneNumbers=15300000001
      # &RegionId=cn-hangzhou
      # &SignName=%E9%98%BF%E9%87%8C%E4%BA%91%E7%9F%AD%E4%BF%A1%E6%B5%8B%E8%AF%95%E4%B8%93%E7%94%A8
      # &SignatureMethod=HMAC-SHA1
      # &SignatureNonce=45e25e9b-0a6f-4070-8c85-2956eda1b466
      # &SignatureVersion=1.0
      # &TemplateCode=SMS_71390007
      # &TemplateParam=%7B%22customer%22%3A%22test%22%7D
      # &Timestamp=2017-07-12T02%3A42%3A19Z
      # &Version=2017-05-25


      # Signature=VP3BzTP7s2nhN06VVQH0TO5i5dE%3D
      # &AccessKeyId=LTAIRu6djaTrSQTb
      # &Action=SendSms
      # &Format=JSON
      # &PhoneNumbers=13969832203
      # &RegionId=cn-hangzhou
      # &SignName=安踏茁壮成长
      # &SignatureMethod=HMAC-SHA1&SignatureNonce=20170813145331958
      # &SignatureVersion=1.0
      # &TemplateCode=SMS_84620016
      # &Timestamp=2017-08-13T14:53:31Z
      # &TemplateParam={\"number\":\"345678\"}
      # &Version=2017-05-25"

      def send(mobile_num, template_code, message_param)
        sms_params = create_params(mobile_num, template_code, message_param)
        Typhoeus.post("https://dysmsapi.aliyuncs.com/",
                 headers: {'Content-Type'=> "application/x-www-form-urlencoded"},
                 body: post_body_data(configuration.access_key_secret, sms_params))
      end

      # 原生参数拼接成请求字符串
      def query_string(params)
        qstring = ''
        params.each do |key, value|
          if qstring.empty?
            qstring += "#{key}=#{value}"
          else
            qstring += "&#{key}=#{value}"
          end
        end
        return qstring
      end

      # 原生参数经过2次编码拼接成标准字符串
      def canonicalized_query_string(params)
        cqstring = ''
        params.each do |key, value|
          if cqstring.empty?
            cqstring += "#{encode(key)}=#{encode(value)}"
          else
            cqstring += "&#{encode(key)}=#{encode(value)}"
          end
        end
        return encode(cqstring)
      end

      # 生成数字签名
      def sign(key_secret, params)
        key = key_secret + '&'
        signature = 'POST' + '&' + encode('/') + '&' + canonicalized_query_string(params)
        sign = Base64.encode64("#{OpenSSL::HMAC.digest('sha1',key, signature)}")
        encode(sign.chomp)  # 通过chomp去掉最后的换行符 LF
      end

      # 组成附带签名的 POST 方法的 BODY 请求字符串
      def post_body_data(key_secret, params)
        body_data = 'Signature=' + sign(key_secret, params) + '&' + query_string(params)
      end

      # 对字符串进行 PERCENT 编码
      def encode(input)
        output = url_encode(input)
      end

      # 生成短信时间戳
      def seed_timestamp
        Time.now.utc.strftime("%FT%TZ")
      end

      # 生成短信唯一标识码，采用到微秒的时间戳
      def seed_signature_nonce
        Time.now.utc.strftime("%Y%m%d%H%M%S%L")
      end

    end

  end
end
