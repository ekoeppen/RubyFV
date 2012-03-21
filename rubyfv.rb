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
  end
  
  def quit
  end
  
  def init_colors
    @use_color = nil
    if @use_color
      Curses.start_color
      Curses.init_pair(1, Curses::COLOR_WHITE, Curses::COLOR_BLACK)
      Curses.init_pair(2, Curses::COLOR_GREEN, Curses::COLOR_BLACK)
      Curses.init_pair(3, Curses::COLOR_RED, Curses::COLOR_BLACK)
    end
    set_normal_color
  end
  
  def set_normal_color
    if @use_color then Curses.stdscr.color_set(1) else Curses.stdscr.attrset(Curses::A_DIM) end
  end
  
  def set_preselected_color
    if @use_color then Curses.stdscr.color_set(2) else Curses.stdscr.attrset(Curses::A_BOLD) end
  end
  
  def set_active_color
    if @use_color then Curses.stdscr.color_set(3) else Curses.stdscr.attrset(Curses::A_STANDOUT) end
  end
  
  def init_screen
    Curses.noecho
    Curses.init_screen
    Curses.stdscr.keypad(true)
    Curses.curs_set(0)
    @screen_length = Curses.lines - 6
    init_colors
    begin
      yield
    ensure
      Curses.close_screen
    end
  end

  def remove_current
    if @lines.length > 0
      @lines.delete_at(@current_line)
      if @current_line > @lines.length - 1
        @current_line = @lines.length - 1
        if @current_line - @current_top < 0 then @current_top = @current_top - 1 end
      end
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
      save_data
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
    save_data
  end

  def done_action
    remove_current
    save_data
  end

  def toggle_start
    a = @lines[@current_line]
    if a.state == 1
      a.state = 2
      save_data
    elsif a.state == 2
      enter_action(a.action)
      remove_current
      save_data
    end
  end

  def toggle_preselect
    a = @lines[@current_line]
    if a.state < 2
      a.state = 1 - a.state
      save_data
    end
  end

  def get_preselected_before(line)
    r = nil
    i = 0
    @lines.each do |l|
      if i <= line and l.state == 1 then r = l end
      i = i + 1
    end
    return r
  end

  def show_page
    i = 0
    Curses.setpos(i + 2, 0)
    Curses.clrtoeol
    for l in @lines[@current_top..-1] do
      Curses.setpos(i + 3, 0)
      set_normal_color
      Curses.addstr(if i == @current_line - @current_top then "-> " else "   " end)
      if l.state == 1
        set_preselected_color
      elsif l.state == 2
        set_active_color
      end
      Curses.addstr(l.action)
      Curses.clrtoeol
      if i == @current_line - @current_top 
        p = get_preselected_before(i)
        if p then
          Curses.setpos(i + 2, 0)
          set_preselected_color
          Curses.addstr("   " + p.action)
          Curses.clrtoeol
        end
      end
      i = i + 1
      if i > @screen_length then break end
    end
    while i <= @screen_length
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
      @current_line = @current_line - 1
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

  def to_s
    r = ""
    @lines.each do |line|
      if line.state == 1 then prefix = "+ "
      elsif line.state == 2 then prefix = "- "
      else prefix = "  "
      end
      r << prefix << line.action << "\n"
    end
    return r
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
        when ?p then toggle_preselect
        when ?s then toggle_start
        when ?d then done_action
        when ?l then load_data
        when ?q then done = true
        end
      end
    end

  end
  
end

if File.exist?(ENV["HOME"] + "/.rubyfvrc") then load(ENV["HOME"] + "/.rubyfvrc") end

focus = RubyFocus.load_data
focus.run
focus.quit

# vim:ts=2:expandtab:sw=2:

