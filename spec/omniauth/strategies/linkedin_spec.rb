require 'spec_helper'
require 'omniauth-linkedin-oauth2'

describe OmniAuth::Strategies::LinkedIn do
  subject {OmniAuth::Strategies::LinkedIn.new(nil)}

  it 'should add a camelization for itself' do
    expect(OmniAuth::Utils.camelize('linkedin')).to eq('LinkedIn')
  end

  describe '#client' do
    it 'has correct LinkedIn site' do
      expect(subject.client.site).to eq('https://api.linkedin.com')
    end

    it 'has correct authorize url' do
      expect(subject.client.options[:authorize_url]).to eq('https://www.linkedin.com/oauth/v2/authorization?response_type=code')
    end

    it 'has correct token url' do
      expect(subject.client.options[:token_url]).to eq('https://www.linkedin.com/oauth/v2/accessToken')
    end

    it 'posts params using the :query mode' do
      expect(subject.options.token_params[:mode]).to eq(:query)
    end
  end

  describe '#callback_path' do
    it 'has the correct callback path' do
      expect(subject.callback_path).to eq('/auth/linkedin/callback')
    end
  end

  describe '#uid' do
    before :each do
      allow(subject).to receive(:raw_info) {{'id' => 'uid'}}
    end

    it 'returns the id from raw_info' do
      expect(subject.uid).to eq('uid')
    end
  end

  describe '#info' do
    before :each do
      allow(subject).to receive(:raw_info) {{}}
    end

    context 'and therefore has all the necessary fields' do
      it {expect(subject.info).to have_key :name}
      it {expect(subject.info).to have_key :email}
      it {expect(subject.info).to have_key :nickname}
      it {expect(subject.info).to have_key :first_name}
      it {expect(subject.info).to have_key :last_name}
      it {expect(subject.info).to have_key :location}
      it {expect(subject.info).to have_key :description}
      it {expect(subject.info).to have_key :image}
      it {expect(subject.info).to have_key :urls}
    end
  end

  describe '#extra' do
    before :each do
      allow(subject).to receive(:raw_info) {{:foo => 'bar'}}
    end

    it {expect(subject.extra['raw_info']).to eq({:foo => 'bar'})}
  end

  describe '#access_token' do
    before :each do
      allow(subject).to receive(:oauth2_access_token) {double('oauth2 access token', :expires_in => 3600, :expires_at => 946688400).as_null_object}
    end

    it {expect(subject.access_token.expires_in).to eq(3600)}
    it {expect(subject.access_token.expires_at).to eq(946688400)}
  end

  describe '#raw_info' do
    before :each do
      access_token = double('access token')
      response     = double('response', :parsed => {:foo => 'bar'})
      expect(access_token).to receive(:get).with('/v1/people/~:(baz,qux)?format=json').and_return(response)

      allow(subject).to receive(:option_fields) {%w(baz qux)}
      allow(subject).to receive(:access_token) {access_token}
    end

    it 'returns parsed response from access token' do
      expect(subject.raw_info).to eq({:foo => 'bar'})
    end
  end

  describe '#authorize_params' do
    subject {OmniAuth::Strategies::LinkedIn.new(nil, nil, nil, options)}
    let(:request) {double('Request', params: {}, cookies: {}, env: {})}

    before do
      allow(subject).to receive(:request) {request}
      OmniAuth.config.test_mode = true
    end

    after {OmniAuth.config.test_mode = false}

    %i[state scope redirect_uri].each do |k|
      describe "#{k} param" do
        let(:options) {{k => 'http://someval'}}

        it 'is supported' do
          expect(subject.authorize_params[k.to_s]).to eq('http://someval')
        end
      end
    end

    describe 'scope' do
      let(:options) {{}}

      it 'sets default scope' do
        expect(subject.authorize_params['scope']).to eq('r_basicprofile r_emailaddress')
      end
    end

    describe 'state' do
      let(:options) {{state: 'some_state'}}

      it 'should set the state parameter' do
        expect(subject.authorize_params['state']).to eq('some_state')
        expect(subject.session['omniauth.state']).to eq('some_state')
      end

      context 'state in params' do
        let(:request) {double('Request', params: {'state' => 'some_state'}, cookies: {}, env: {})}

        it 'should set the omniauth.state dynamically' do
          expect(subject.authorize_params['state']).to eq('some_state')
          expect(subject.session['omniauth.state']).to eq('some_state')
        end
      end
    end

  end

  describe '#option_fields' do
    it 'returns options fields' do
      allow(subject).to receive(:options).and_return(double('options', :fields => ['foo', 'bar']).as_null_object)
      expect(subject.send(:option_fields)).to eq(['foo', 'bar'])
    end

    it 'http avatar image by default' do
      allow(subject).to receive(:options).and_return(double('options', :fields => ['picture-url']))
      allow(subject.options).to receive(:[]).with(:secure_image_url).and_return(false)
      expect(subject.send(:option_fields)).to eq(['picture-url'])
    end

    it 'https avatar image if secure_image_url truthy' do
      allow(subject).to receive(:options).and_return(double('options', :fields => ['picture-url']))
      allow(subject.options).to receive(:[]).with(:secure_image_url).and_return(true)

      expect(subject.send(:option_fields)).to eq(['picture-url;secure=true'])
    end
  end
end
