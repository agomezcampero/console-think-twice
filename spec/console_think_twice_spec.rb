# frozen_string_literal: true

RSpec.describe ConsoleThinkTwice do
  let(:input) { instance_double(IO) }
  let(:output) { StringIO.new }
  let!(:author) { Author.create!(name: "Ursula") }

  before do
    described_class.configure do |config|
      config.enabled = true
      config.input = input
      config.output = output
      config.interactive = true
      config.label = nil
    end
    described_class.install!
    answer "y"
  end

  after { described_class.disable! }

  def answer(response)
    allow(input).to receive(:gets).and_return("#{response}\n")
  end

  def prompts
    output.string.scan("Confirm? (y/N)").size
  end

  describe "destroying a single record" do
    it "asks before destroying and goes ahead on y" do
      expect { author.destroy! }.to change(Author, :count).by(-1)
      expect(output.string).to include("This will permanently destroy Author ##{author.id}.")
      expect(prompts).to eq(1)
    end

    it "aborts on anything else, leaving the record alone" do
      answer "n"

      expect { author.destroy! }.to raise_error(described_class::Aborted, /Nothing was destroyed/)
      expect(Author.exists?(author.id)).to be(true)
    end

    it "guards destroy as well as destroy!" do
      answer "n"

      expect { author.destroy }.to raise_error(described_class::Aborted)
    end

    it "skips the prompt when forced" do
      expect { author.destroy!(force: true) }.to change(Author, :count).by(-1)
      expect(input).not_to have_received(:gets)
    end

    it "says when the call skips callbacks" do
      author.delete

      expect(output.string).to include("This will permanently delete, skipping callbacks, Author ##{author.id}.")
    end

    it "does not ask about a record that was never saved" do
      Author.new.destroy

      expect(prompts).to eq(0)
    end

    it "lists the associations that will cascade" do
      author.destroy!

      expect(output.string).to include("Cascades to: books\n")
    end

    it "asks once for the whole cascade, not once per dependent record" do
      author.books.create!(title: "A Wizard of Earthsea")
      author.books.create!(title: "The Dispossessed")

      expect { author.destroy! }.to change(Book, :count).by(-2)
      expect(prompts).to eq(1)
    end
  end

  describe "destroying a relation" do
    before { Author.create!(name: "Le Guin") }

    it "reports how many records are involved" do
      expect { Author.destroy_all }.to change(Author, :count).to(0)
      expect(output.string).to include("This will permanently destroy 2 Authors.")
      expect(prompts).to eq(1)
    end

    it "keeps the model name singular for a single record" do
      Author.where(name: "Ursula").destroy_all

      expect(output.string).to include("This will permanently destroy 1 Author.")
    end

    it "guards delete_all" do
      answer "n"

      expect { Author.delete_all }.to raise_error(described_class::Aborted, /Nothing was deleted/)
      expect(Author.count).to eq(2)
    end

    it "guards a has_many collection" do
      author.books.create!(title: "A Wizard of Earthsea")
      answer "n"

      expect { author.books.destroy_all }.to raise_error(described_class::Aborted)
      expect(author.books.count).to eq(1)
    end

    it "skips the prompt when forced" do
      expect { Author.destroy_all(force: true) }.to change(Author, :count).to(0)
      expect(prompts).to eq(0)
    end

    it "does not ask when nothing matches" do
      Author.where(name: "Nobody").destroy_all

      expect(prompts).to eq(0)
    end
  end

  describe "the environment label" do
    it "names it in the prompt so the stakes are obvious" do
      described_class.configure { |config| config.label = "production" }

      author.destroy!

      expect(output.string).to include("This will permanently destroy Author ##{author.id} in production.")
    end
  end

  describe "without a terminal to confirm on" do
    before { described_class.configure { |config| config.interactive = false } }

    it "refuses rather than guessing" do
      expect { Author.destroy_all }.to raise_error(described_class::Aborted, /pass `force: true`/)
      expect(Author.count).to eq(1)
    end

    it "still allows a forced call" do
      expect { Author.destroy_all(force: true) }.to change(Author, :count).to(0)
    end
  end

  describe "when the guard is not active" do
    before { described_class.disable! }

    it "leaves destructive calls alone" do
      expect { Author.destroy_all }.to change(Author, :count).to(0)
      expect(prompts).to eq(0)
    end
  end

  describe ".install!" do
    it "does nothing when disabled by configuration" do
      described_class.disable!
      described_class.configure { |config| config.enabled = false }

      expect(described_class.install!).to be(false)
      expect(described_class).not_to be_active
    end
  end

  describe "configuration" do
    it "reads the opt-out from the environment" do
      config = described_class::Configuration.new
      expect(config.enabled?).to be(true)

      ENV["CONSOLE_THINK_TWICE"] = "0"
      expect(config.enabled?).to be(false)
    ensure
      ENV.delete("CONSOLE_THINK_TWICE")
    end
  end
end
