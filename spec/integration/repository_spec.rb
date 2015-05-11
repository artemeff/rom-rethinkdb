require 'spec_helper'

require 'virtus'

describe 'RethinkDB repository' do
  include PrepareDB

  let(:repository) { rom.repositories[:default] }
  let(:setup) { ROM.setup(:rethinkdb, db_options.merge(db: 'test_db')) }
  subject(:rom) { setup.finalize }

  before do
    create_table('test_db', 'users')

    setup.relation(:users) do
      def with_name(name)
        filter(name: name)
      end

      def only_names
        pluck('name')
      end

      def by_name
        order_by('name')
      end

      def names_on_street(street)
        filter(street: street).order_by('name').pluck(:name)
      end
    end

    class User
      include Virtus.value_object

      values do
        attribute :id, Integer
        attribute :name, String
        attribute :street, String
      end
    end

    setup.mappers do
      define(:users) do
        model(User)
        register_as(:entity)
      end
    end

    # fill table
    [
      { id: 1, name: 'John', street: 'Main Street' },
      { id: 2, name: 'Joe', street: '2nd Street' },
      { id: 3, name: 'Jane', street: 'Main Street' }
    ].each do |data|
      repository.send(:rql).table('users').insert(data)
        .run(repository.connection)
    end
  end

  after do
    drop_table('test_db', 'users')
  end

  describe 'env#relation' do
    it 'returns mapped object' do
      jane = rom.relation(:users).as(:entity).with_name('Jane').to_a.first

      expect(jane.name).to eql('Jane')
    end

    it 'returns specified fields' do
      user = rom.relation(:users).as(:entity).only_names.to_a.first

      expect(user.id).to be_nil
      expect(user.name).not_to be_nil
      expect(user.street).to be_nil
    end

    it 'returns ordered data' do
      results = rom.relation(:users).as(:entity).by_name.to_a

      expect(results[0].name).to eql('Jane')
      expect(results[1].name).to eql('Joe')
      expect(results[2].name).to eql('John')
    end

    it 'returns data with combined conditions' do
      results = rom.relation(:users).as(:entity).names_on_street('Main Street').to_a

      expect(results[0].id).to be_nil
      expect(results[0].name).to eql('Jane')
      expect(results[0].street).to be_nil

      expect(results[1].id).to be_nil
      expect(results[1].name).to eql('John')
      expect(results[1].street).to be_nil
    end
  end

  describe 'repository#dataset?' do
    it 'returns true if a collection exists' do
      expect(repository.dataset?(:users)).to be(true)
    end

    it 'returns false if a does not collection exist' do
      expect(repository.dataset?(:not_here)).to be(false)
    end
  end
end