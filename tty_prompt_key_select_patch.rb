# Monkey patch to add one-key selection to TTY::Prompt's List menu
# This patch allows using the `key:` option with `prompt.select` choices.

require 'tty/prompt'

module TTY
  class Prompt
    class List
      alias_method :orig_keypress, :keypress

      def keypress(event)
        if !filterable? && (choice = choices.find_by(:key, event.value))
          unless choice.disabled?
            @active = choices.index(choice) + 1
            @done = true
          end
        else
          orig_keypress(event)
        end
      end
    end
  end
end
