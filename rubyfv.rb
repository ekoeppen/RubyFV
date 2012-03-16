#!/usr/bin/env ruby

require 'curses'
require 'yaml'
require 'thread'
require 'date'

class Line
  attr_accessor :action
  attr_accessor :state

  def initialize(theAction, aState = 0)
    @action = theAction
    @state = aState
  end
end


class RubyFocus
  
  attr_accessor :lines
  attr_accessor :current_top
  attr_accessor :screen_length
  attr_accessor :current_line
 
  def initialize
    @lines = Array.new
    @current_top = 0
    @current_line = 0
    @screen_length = 20
  end
  
  def quit
  end
  
  def init_colors
    @use_color = nil
    if @use_color
      Curses.start_color
      Curses.init_pair(1, Curses::COLOR_WHITE, Curses::COLOR_BLACK)
      Curses.init_pair(2, Curses::COLOR_RED, Curses::COLOR_BLACK)
      Curses.init_pair(3, Curses::COLOR_GREEN, Curses::COLOR_BLACK)
    end
    set_normal_color
  end
  
  def set_normal_color
    if @use_color then Curses.stdscr.color_set(1) else Curses.stdscr.attrset(Curses::A_BOLD) end
  end
  
  def set_active_color
    if @use_color then Curses.stdscr.color_set(2) else Curses.stdscr.attrset(Curses::A_STANDOUT) end
  end
  
  def set_done_color
    if @use_color then Curses.stdscr.color_set(3) else Curses.stdscr.attrset(Curses::A_DIM) end
  end
  
  def init_screen
    Curses.noecho
    Curses.init_screen
    Curses.stdscr.keypad(true)
    Curses.curs_set(0)
    init_colors
    begin
      yield
    ensure
      Curses.close_screen
    end
  end
  
  def enter_action(action = nil)
    clear = false
    if not action
      Curses.echo; Curses.curs_set(1)
      Curses.setpos(0, 0)
      Curses.addstr("New action: ")
      action = Curses.getstr
      Curses.noecho; Curses.curs_set(0)
      Curses.setpos(0, 0)
      Curses.clrtoeol
    end
    if action.length > 0
      @lines << Line.new(action)
    end
  end

  def edit_action
    Curses.echo; Curses.curs_set(1)
    Curses.setpos(0, 0)
    Curses.addstr("Edit action: ")
    @lines[@current_line] = Line.new(Curses.getstr)
    Curses.noecho; Curses.curs_set(0)
    Curses.setpos(0, 0)
    Curses.clrtoeol
  end

  def done_action
     @lines[@current_line].state = 2
  end

  def toggle_action
    a = @lines[@current_line]
    if a.state < 2
      if a.state == 1
        enter_action(a.action)
      end
      a.state = a.state + 1
    end
  end

  def show_page
    # Curses.setpos(2, Curses.cols - 15)
    # Curses.addstr(" " + @current_line.to_s + " " + @current_top.to_s + "   ")
    i = 0
    for l in @lines[@current_top..-1] do
      Curses.setpos(i + 3, 0)
      Curses.addstr(if i == @current_line - @current_top then "-> " else "   " end)
      if l.state == 1
        set_active_color
      elsif l.state == 2
        set_done_color
      end
      Curses.addstr(l.action)
      if l.state != 0 then
        set_normal_color
      end
      Curses.clrtoeol
      i = i + 1
      if i > @screen_length then break end
    end
    while i < @screen_length
      Curses.setpos(i + 3, 0)
      Curses.clrtoeol
      i = i + 1
    end
    Curses.refresh
  end

  def next_line
    if @current_line < @lines.length - 1
      begin
        @current_line = @current_line + 1
      end
    else
      @current_line = 0
      @current_top = 0
    end
    if @current_line - @current_top > @screen_length then @current_top = @current_top + 1 end
  end
  
  def previous_line
    if @current_line > 0 then
      begin
        @current_line = @current_line - 1
      end
    else
      @current_line = @lines.length - 1
      @current_top = @lines.length - @screen_length - 1
      if @current_top < 0 then @current_top = 0 end
    end
    if @current_line - @current_top < 0 then @current_top = @current_top - 1 end
  end

  def next_page
    if @current_line < @lines.length - @screen_length then
      @current_line = @current_line + @screen_length
    else
      @current_line = @lines.length - 1
    end
    @current_top = @current_line - @screen_length
    if @current_top < 0 then @current_top = 0 end
  end
  
  def previous_page
    if @current_line - @screen_length > 0 then
      @current_line = @current_line - @screen_length
    else
      @current_line = 0
    end
    @current_top = @current_line - @screen_length
    if @current_top < 0 then @current_top = 0 end
  end

  def first_line
    @current_line = 0
    @current_top = 0
  end
  
  def last_line
    @current_line = @lines.length - 1
    @current_top = @current_line - @screen_length
    if @current_top < 0 then @current_top = 0 end
  end

  def from_s(string)
    @lines = Array.new
    string.each_line do |line|
      line.rstrip!
      if line.start_with? "  "
        state = 0
      elsif line.start_with? "+ "
        state = 1
      else
        state = 2
      end
      line.slice!(0..1)
      @lines << Line.new(line, state)
    end
    @current_line = 0
  end

  def RubyFocus.load_data
    f = nil
    begin
      File.open("tasks.txt") do |file|
        f = RubyFocus.new
        f.from_s(file.read)
      end
    rescue
      f = RubyFocus.new
    end
    return f
  end

  def run
    init_screen do
      done = false
      while not done
        show_page
        c = Curses.getch
        case c
        when Curses::Key::UP then previous_line
        when Curses::Key::DOWN then next_line
        when Curses::Key::PPAGE then previous_page
        when Curses::Key::NPAGE then next_page
        when Curses::Key::HOME then first_line
        when Curses::Key::END then last_line
        when ?e then edit_action
        when ?a then enter_action
        when ?s then toggle_action
        when ?d then done_action
        when ?q then done = true
        end
      end
    end

  end
  
end

focus = RubyFocus.load_data
focus.run
focus.quit

# vim:ts=2:expandtab:sw=2:
