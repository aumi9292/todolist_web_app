require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "sinatra/contrib"

ERRS = { 
  length: "Must enter a valid length between 1 and 100 characters",
  unique: "Must enter a unique name"
}

SUCC = { 
  list: "The list has been created",
  todo: "The todo has been created",
  edit_list: "The list name has been updated",
  delete: "The list has been deleted",
  del_todo: "The todo has been deleted",
  mark_todo: "The todo has been updated",
  all_todos: "All todos have been marked as complete"
}

SUBMIT_OR_CANCEL_BTN = [
  "<input type=\"submit\" value=\"Save\">",
  "<a href=\"/lists\">Cancel</a>"
].join("\n")

DELETE_BTN = "<a class=\"delete\" href=\"\">Delete</a>"

configure do 
  set :sessions, true 
  set :session_secret, "secret"
  set :erb, :escape_html => true
end 

before do
  session[:lists] ||= []
  @lists = session[:lists]
  @list_id = params[:list_id].to_i
  @list = @lists[@list_id] || {}
  @list_name = @list[:name]
end 

helpers do 
  def list_completed?(list)
    list[:todos].length > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def todos(list)
    list[:todos].count
  end 

  def name(list)
    list[:name].capitalize
  end 

  def format_lists(lists)
    order_lists!(lists).map.with_index { |list, idx| yield idx, name(list), todos(list) }.join("\n") 
  end 

  def order_lists!(lists)
    lists.sort_by! { |list| list_completed?(list) ? 1 : 0 }
  end 

  def flashify(msg, status)
    "<div class=\"flash #{status}\"><p>#{msg}</p></div>"
  end 

  def listify(list_id, name, count)
    li_class = list_completed?(@lists[list_id]) ? "class=\"complete\"" : ""
    "<li #{li_class}><a href=\"/lists/#{list_id}\"><h2>#{name}</h2> <p>#{remaining(list_id, count)}</p></a></li>"
  end 

  def remaining(list_id, count)
    rem = @lists[list_id][:todos].count { |todo| !todo[:completed] }
    "#{rem} / #{count}"
  end 

  def titlefy    
    <<-HTML
    <h2>#{@list[:name]}</h2>
      <ul>
        <li>
          <form action="/lists/#{@list_id}/todos/all_complete" method="post">
            <button class="check" type="submit">Complete All</button>
          </form>       
        </li>  
          <li><a class=\"edit\" href=\"/lists/#{@list_id}/edit\">Edit list</a></li>
      </ul>
    HTML
  end 

  def edit_list_titlefy
    "<h2> Editing '#{@list[:name]}' </h2>"
  end 

  def delete_todo(idx)
    <<-HTML
      <form action="/lists/#{@list_id}/todos/#{idx}/delete" method="post" class="delete">
        <button type="submit">Delete</button>
      </form>
    HTML
  end 

  def mark_todo(idx)
    li_class = "class=\"complete\"" if @list[:todos][idx][:completed]
    <<-HTML 
    <li #{li_class}>
      <form action="/lists/#{@list_id}/todos/complete" method="post" class="check">
        <input type="hidden" name="completed" value="#{idx}" />
        <button type="submit">Complete</button>
      </form>
    HTML
  end 

  def namify(todo)
    "<h3>#{todo[:name]}</h3>"
  end 

  def todo_listify
    @list[:todos].map
                 .with_index do |todo, idx| 
                  "#{mark_todo(idx)} #{namify(todo)} #{delete_todo(idx)}</li>"
                 end.join
  end 

  def unique(list_name)
    @lists.none? { |list| list[:name] == list_name.capitalize }
  end 

  def valid_length(list_name)
    list_name.length.between?(1, 100)
  end 

  def error_msg(name)
    return ERRS[:unique] unless unique(name)
    return ERRS[:length] unless valid_length(name)
  end 

  def todo_name_error(name)
    return ERRS[:length] unless valid_length(name)
  end
end 

get "/" do
  redirect "/lists"
end

#show all lists
get "/lists" do 
  erb :lists
end 

#show new list page
get "/lists/new" do 
  erb :new_list 
end 

#show one list 
get "/lists/:list_id" do 
  @lists = session[:lists]
  @list_id = params[:list_id].to_i
  @list = @lists[@list_id]

  erb :list
end

#helper for mark todo complete route
def change_todo_status(todo)
  todo[:completed] = !todo[:completed]
end
#mark todo complete 
post "/lists/:list_id/todos/complete" do 
  @lists = session[:lists]
  @list_id = params[:list_id].to_i
  @list = @lists[@list_id]
  @todo_idx = params[:completed].to_i
  @todo = @list[:todos][@todo_idx]
  change_todo_status(@todo)
  session[:success] = SUCC[:mark_todo]
  redirect "/lists/#{@list_id}"
end 
 
#mark all todos complete 
post "/lists/:list_id/todos/all_complete" do 
  @lists = session[:lists]
  @list_id = params[:list_id].to_i
  @list = @lists[@list_id]
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] == SUCC[:all_todos]
  redirect "/lists/#{@list_id}"
end 

#delete todo
post "/lists/:list_id/todos/:todo_id/delete" do 
  @list[:todos].delete_at(params[:todo_id].to_i)
  session[:success] = SUCC[:del_todo]
  redirect "/lists/#{@list_id}"
end 

#add todo to one list 
post "/lists/:list_id/todos" do 
  @list_id = params[:list_id].to_i
  @list = @lists[@list_id]
  @todo_name = params[:todo_name].strip.capitalize
  name_err = todo_name_error(@todo_name)
  name_err ? re_render(:list, name_err) : todo_succ_redir("/lists/#{@list_id}", SUCC[:todo])
end 

#helper for "/list" route
def re_render(page, err)
  session[:error] = err
  erb page
end 

#helper for "/list" route
def succ_redir(page, succ, update = false)
  update ? update_list(update) : add_list(@list_name)
  session[:success] = succ
  redirect page
end 

#helper for "/list" route
def add_list(list_name)
  session[:lists] << { name: @list_name, todos: [] }
end 

#helper to update list rather than create a new one 
def update_list(new_name) 
  session[:lists][@list_id][:name] = new_name
end

def todo_succ_redir(page, succ)
  session[:success] = succ
  @list[:todos] << { name: @todo_name, completed: false }
  redirect page
end 

#add new list into lists or re-render page if errors with list name 
post "/lists" do 
  @list_name = params[:list_name].strip.capitalize
  name_err = error_msg(@list_name)
  name_err ? re_render(:new_list, name_err) : succ_redir("/lists", SUCC[:list])
end 

#edit list name 
get "/lists/:list_id/edit" do 
  erb :edit_list
end 

#change list name or re-render page if errors with new list name 
post "/lists/:list_id/edit" do 
  @new_name = params[:list_name].strip.capitalize
  name_err = error_msg(@new_name)
  name_err ? re_render(:edit_list, name_err) : succ_redir("/lists", SUCC[:edit_list], @new_name)
end 

#delete list 
post "/lists/:list_id/delete" do 
  @lists.delete_at(@list_id)
  session[:success] = SUCC[:delete]
  redirect :lists
end 






