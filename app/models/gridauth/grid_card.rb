require "openssl"

module Gridauth
  # A grid card belonging to a user. Only HMAC digests of the cell values are
  # stored; the plaintext is shown once, when the card is issued.
  #
  # Lifecycle: pending (issued, awaiting confirmation) -> active -> revoked.
  # A user has at most one active card; activating a new card revokes the old
  # one, which is how rotation works.
  class GridCard < ApplicationRecord
    STATUSES = %w[pending active revoked].freeze
    SERIAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".chars.freeze

    belongs_to :user, class_name: Gridauth.config.user_class, inverse_of: :grid_cards

    serialize :cell_digests, coder: JSON

    enum :status, STATUSES.index_by(&:itself), validate: true

    validates :serial, presence: true, uniqueness: true
    validates :row_count, :column_count, :cell_length, numericality: { only_integer: true, greater_than: 0 }
    validates :salt, :cell_digests, presence: true

    # Creates a pending card for `user` and returns `[card, grid]`.
    def self.issue_for!(user, grid: Grid.generate)
      transaction do
        user.grid_cards.pending.delete_all

        card = user.grid_cards.build(
          serial: generate_serial,
          row_count: grid.rows,
          column_count: grid.columns,
          cell_length: grid.values.each_value.first.length,
          salt: SecureRandom.hex(16)
        )
        card.cell_digests = grid.values.to_h { |key, value| [ key, card.send(:digest_cell, key, value) ] }
        card.save!

        [ card, grid ]
      end
    end

    def self.generate_serial
      loop do
        serial = Array.new(8) { SERIAL_ALPHABET[SecureRandom.random_number(SERIAL_ALPHABET.size)] }
          .each_slice(4).map(&:join).join("-")
        break serial unless exists?(serial:)
      end
    end

    def column_labels = Grid.column_labels(column_count)
    def row_labels = Grid.row_labels(row_count)
    def cell_keys = Grid.cell_keys(row_count, column_count)

    # Cells the user must answer next, e.g. ["B2", "F4", "J1"].
    #
    # A challenge stays the same until it has been answered correctly, so
    # signing in over and over cannot be used to "shop" for cells an attacker
    # happens to know.
    def challenge_cells
      self[:challenge_cells].to_s.split(",")
    end

    def issue_challenge!
      with_lock do
        if challenge_cells.empty?
          size = Gridauth.config.challenge_size.clamp(1, cell_keys.size)
          cells = cell_keys.sample(size, random: SecureRandom).sort_by { |key| cell_keys.index(key) }
          update!(challenge_cells: cells.join(","))
        end
      end
      challenge_cells
    end

    # Checks answers (a hash of cell => value) against the current challenge.
    # Returns :success, :invalid or :locked. Wrong answers count towards the
    # lockout; a correct answer resets the count and retires the challenge.
    def verify_challenge(answers)
      answers = (answers || {}).to_h.transform_keys { |key| key.to_s.upcase }

      with_lock do
        if locked?
          :locked
        elsif challenge_cells.empty?
          :invalid
        elsif challenge_cells.map { |cell| cell_matches?(cell, answers[cell]) }.all?
          update!(challenge_cells: nil, failed_attempts: 0, locked_until: nil)
          :success
        else
          register_failed_attempt
        end
      end
    end

    def locked?
      locked_until.present? && locked_until.future?
    end

    def activate!
      transaction do
        user.grid_cards.active.where.not(id: id).find_each(&:revoke!)
        update!(status: "active", activated_at: Time.current, challenge_cells: nil,
          failed_attempts: 0, locked_until: nil, use_count: 0)
      end
    end

    def revoke!
      update!(status: "revoked", revoked_at: Time.current, challenge_cells: nil)
    end

    def record_use!
      update!(use_count: use_count + 1, last_used_at: Time.current)
    end

    # When the card should be replaced based on age, if age-based rotation is on.
    def rotation_due_at
      activated_at + Gridauth.config.rotation_period if activated_at && Gridauth.config.rotation_period
    end

    def rotation_due?
      return false unless active?

      expired = rotation_due_at.present? && rotation_due_at <= Time.current
      worn_out = Gridauth.config.rotate_after_uses.present? && use_count >= Gridauth.config.rotate_after_uses
      expired || worn_out
    end

    private
      def cell_matches?(cell, answer)
        expected = cell_digests[cell]
        expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, digest_cell(cell, answer))
      end

      def digest_cell(cell, value)
        OpenSSL::HMAC.hexdigest("SHA256", Gridauth.config.secret_key, [ salt, cell, normalize(value) ].join(":"))
      end

      def normalize(value)
        value = value.to_s.gsub(/\s+/, "")
        Gridauth.config.case_sensitive ? value : value.upcase
      end

      def register_failed_attempt
        attempts = failed_attempts + 1
        if attempts >= Gridauth.config.max_failed_attempts
          update!(failed_attempts: 0, locked_until: Time.current + Gridauth.config.lockout_period)
          :locked
        else
          update!(failed_attempts: attempts)
          :invalid
        end
      end
  end
end
