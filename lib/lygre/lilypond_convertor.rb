# encoding: UTF-8

# REVISION 6

class LilypondConvertor

  # true - print if given; false - ignore; 'always' - print even if empty
  DEFAULT_SETTINGS = {
                      version: true,
                      notes: true,
                      lyrics: true,
                      header: true,
                      cadenza: false
                     }

  DEFAULT_CLEF = GabcClef.new(pitch: :c, line: 4, bemol: false)

  # maps gabc divisiones to lilypond bars
  BARS = {
#            ':' => '\divisioMaxima \bar ""',
            ';' => '\halfBar',
#            '::' => '\finalis \bar ""',
#            ',' => '\divisioMinima \bar ""',
          ':' => '\bar "|"',
#          ';' => '\bar "|"',
          '::' => '\bar "||"',
          ',' => '\bar "\'"',
          '`' => '\breathe \bar ""'
         }


  def initialize(settings={})
    @settings = DEFAULT_SETTINGS.dup.update(settings)

    # todo: make it possible to freely choose absolute c _pitch_
    @c_pitch = NoteFactory["c''"]

    @lily_scale = [:c, :d, :e, :f, :g, :a, :b]
    @gabc_lines = ['', :d, :f, :h, :j]
  end

  # converts GabcScore to Lilypond source
  def convert(score)
    header = score.header.keys.sort.collect do |k|
      "    #{k} = \"#{score.header[k]}\""
    end.join "\n"

    notes = []
    lyrics = []

    clef = DEFAULT_CLEF
    @gabc_reader = GabcPitchReader.new clef.pitch, clef.line

    score.music.words.each_with_index do |word,i|
      current = word_notes(word, clef)
      if @settings[:cadenza] &&
         ! (notes.empty? || current.empty? ||
            notes.last.include?('\bar') || current.include?('\bar') ||
            notes.last.include?('\halfBar') ||
            current.include?('\halfBar'))
        notes << '\bar ""'
      end
      notes << current unless current.empty?
      lyrics << word_lyrics(word)
    end

    r = ''

    r += "\\version \"2.18.0\"\n\n" if @settings[:version]
    r += %q(halfBar = {
  \once \override BreathingSign.stencil = #ly:breathing-sign::divisio-maior
  \once \override BreathingSign.Y-offset = #0
  \breathe
  \bar ""
}

squiggle = {
  \once \override NoteHead.stencil = #ly:text-interface::print
  \once \override NoteHead.text = \markup \musicglyph "scripts.prall"
}

ictus = \markup \halign #-13 \musicglyph "scripts.ictus"

whiteNote = \once \override NoteHead.duration-log = #1

\layout {
  ragged-right = ##t
  \context {
    \Score
    \omit Stem
    \omit Beam
    \omit Flag
    \omit TimeSignature
    \override Slur.direction = #DOWN
    \override SpacingSpanner.common-shortest-duration = #(ly:make-moment 1/16)
  }
}
    
)
    
    r += "\\score {\n"

    if @settings[:notes] and
        (notes.size > 0 or @settings[:notes] == 'always') then
      r += "  \\absolute {\n"

      if @settings[:cadenza] then
        r += "    \\cadenzaOn\n"
      end
      
      r += "    #{notes.join(" ")}\n" +
        "  }\n"
    end

    if @settings[:lyrics] and
        (lyrics.size > 0 or @settings[:lyrics] == 'always') then
      r += "  \\addlyrics {\n" +
        "    #{lyrics.join(" ")}\n" +
        "  }\n"
    end

    if @settings[:header] and
        (header.size > 0 or @settings[:header] == 'always') then
      r += "  \\header {\n" +
        "#{header}\n" +
        "  }\n"
    end

    r += "}\n"

    return r
  end

  # returns the output of #convert 'minimized', with whitespace reduced
  # and normalized (useful for testing)
  def convert_min(score)
    convert(score).gsub(/\s+/, ' ').strip
  end

  # makes a melisma from a group of notes
  def melisma(notes)
    i = notes[0].to_s.index('^')
    if i.nil? then i = -1 end
    notes[0] = (notes[0].to_s.insert(i,'64(')).to_sym
    i = notes[-1].to_s.index('^')
    if i.nil? then i = -1 end
    notes[-1] = (notes[-1].to_s.insert(i,'4)')).to_sym
    return notes
  end

  def word_notes(word, clef)
    r = []
    word.each_syllable do |syl|
      notes = syl.notes

      if notes.empty? then
        r << 's'
      else
        sylnotes = []
        notes.each do |n|
          if n.is_a? GabcNote then
            pitch = @gabc_reader.pitch(n.pitch)
            sylnotes << NoteFactory.lily_abs_pitch(pitch)
            case n.shape
            when :vv
                sylnotes << sylnotes[-1]
            when :sss
                sylnotes << sylnotes[-1]
                sylnotes << sylnotes[-1]
            when :w
                sylnotes[-1] = ('\squiggle ' + sylnotes[-1].to_s).to_sym
            end
            
            c = n.rhythmic_signs.to_s.chars
            while ! c.empty? do
                case c[0]
                when ?.
                    sylnotes[-1] = ('\whiteNote ' + sylnotes[-1].to_s).to_sym
                    if c[1] == ?.
                        sylnotes[-2] = ('\whiteNote ' + sylnotes[-2].to_s).to_sym
                        c.shift
                    end
                when ?_
                    sylnotes[-1] = (sylnotes[-1].to_s + '^-').to_sym
                    if c[1] == ?_
                        sylnotes[-2] = + (sylnotes[-2].to_s + '^-').to_sym
                        c.shift
                    end
                when ?'
                    sylnotes[-1] = (sylnotes[-1].to_s + '^\ictus').to_sym
                end
                c.shift
            end
#            puts n.pitch
#            puts n.text_value
#            puts n.initio_debilis
#            puts n.shape
#            puts n.rhythmic_signs
#            puts n.accent
#            puts defined?(n.rhythmic_signs)
          elsif n.is_a? GabcDivisio then
            divisio = n.type
            unless BARS.has_key? divisio
              raise RuntimeError.new "Unhandled bar type '#{n.type}'"
            end

            sylnotes << BARS[divisio].dup

          elsif n.is_a? GabcClef then
            @gabc_reader = GabcPitchReader.new n.pitch, n.line

          else
            raise RuntimeError.new "Unknown music content #{n}"
          end
        end

        if notes.size >= 2 then
          sylnotes = melisma sylnotes
        end
        r += sylnotes
      end
    end
    return r.join ' '
  end

  def word_lyrics(word)
    word.collect do |syll|
      l = syll.lyrics

      if syll.lyrics.start_with? '*' then
        l = '"' + syll.lyrics + '"'
      end

      if syll.lyrics.include? '<' then
        l = syll.lyrics.gsub(/<i>([^<]+)<\/i>/) do |m|
          '\italic{' + $1 + '}'
        end
        l = '\markup{'+l+'}'
      end

      if syll.notes.size == 1 and
          syll.notes.first.is_a? GabcDivisio and
          syll.lyrics.size > 0 then

        unless l.start_with? '\markup'
          l = '\markup{'+l+'}'
        end
        l = '\set stanza = '+l
      end
      
      if syll.lyrics.empty? and
           ! syll.notes.first.is_a? GabcDivisio and
           ! syll.notes.first.is_a? GabcClef then
          l = '_'
      end

      l
    end.join ' -- '
  end
end
