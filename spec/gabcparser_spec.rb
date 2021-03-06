# encoding: utf-8

require 'spec_helper'

describe GabcParser do
  before :each do
    # beginning of the Populus Sion example
    @src = "name: Populus Sion;\n%%\n
(c3) Pó(eh/hi)pu(h)lus(h) Si(hi)on,(hgh.) *(;)
ec(hihi)ce(e.) Dó(e.f!gwh/hi)mi(h)nus(h) vé(hi)ni(ig/ih)et.(h.) (::)"
    @parser = GabcParser.new
  end

  describe '#parse' do
    it 'returns ScoreNode' do
      @parser.parse(@src).should be_kind_of Gabc::ScoreNode
    end
  end

  describe 'header' do
    it 'two subsequent header fields' do
      str = "name:Intret in conspectu;\noffice-part:Introitus;\n"
      @parser.parse(str, root: :header).should be_truthy
    end

    it 'comment+header field' do
      str = "%comment\nname:Intret in conspectu;\n"
      @parser.parse(str, root: :header).should be_truthy
    end

    describe 'header field' do
      def rparse(str)
        @parser.parse(str, root: :header)
      end

      it 'accepts normal header field' do
        rparse("name: Populus Sion;\n").should be_truthy
      end

      it 'accepts empty header field' do
        rparse("name:;\n").should be_truthy
      end

      it 'accepts accentuated characters' do
        rparse("name:Adorábo;\n").should be_truthy
      end

      it 'accepts value with semicolons' do
        rparse("name: 1; 2; 3;\n").should be_truthy
      end

      it 'accepts multi-line value' do
        rparse("name: 1\n2;;\n").should be_truthy
      end
    end
  end

  describe 'lyrics_syllable rule' do
    def rparse(str)
      @parser.parse(str, root: :lyrics_syllable)
    end

    it 'does not accept space alone' do
      rparse(' ').should be nil
    end

    it 'may end with space' do
      rparse('hi ').should be_truthy
    end

    it 'may contain space' do
      rparse('hi :').should be_truthy
    end

    it 'may contain several spaces' do
      rparse('hi   :').should be_truthy
    end

    it 'may contain several space-separated chunks' do
      rparse('hi hey :').should be_truthy
    end

    it 'does not accept string beginning with space' do
      rparse(' aa').should be nil
    end

    it 'accepts ascii characters' do
      rparse('aa').should be_truthy
    end

    it 'accepts characters with accents' do
      rparse('áéíóúý').should be_truthy
    end

    it 'accepts numbers' do
      rparse('12').should be_truthy
    end
  end

  describe 'regular_word_character rule' do
    it 'does not accept space' do
      @parser.parse(' ', root: :regular_word_character).should be nil
    end
  end

  describe 'music' do
    def rparse(str)
      @parser.parse(str, root: :music)
    end

    it 'copes with divisions between notes' do
      rparse('(a,b)').should be_truthy
    end

    it 'custos-division-clef' do
      rparse('(z0::c3)').should be_truthy
    end

    it 'division-clef' do
      rparse('(::c3)').should be_truthy
    end

    it 'custos-division' do
      rparse('(z0::)').should be_truthy
    end
  end

  describe 'comments in body' do
    def rparse(str)
      @parser.parse(str, root: :body)
    end

    it 'comment alone is ok' do
      rparse('% hi').should be_truthy
    end

    it 'comment with trailing whitespace is ok' do
      rparse('% hi ').should be_truthy
    end

    it 'comment after note is ok' do
      rparse('(h) % hi').should be_truthy
    end

    it 'commented note is ok' do
      rparse('%(h)').should be_truthy
    end

    it 'two subsequent comments are ok' do
      rparse("%a\n%b").should be_truthy
    end

    it 'comment immediately after note' do
      rparse('(a)%comment').should be_truthy
    end
  end
end
