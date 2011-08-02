require "json"
Alegato.controllers do
  layout :admin
  get "/admin" do
    @docs = Document.all
    render "admin/doc_list", 
  end
  get :doc_import, "/admin/import" do
    render "admin/import"
  end
  put :doc_import,"/admin/import" do
    if params[:text]
      d = Document.new
      d.title = params[:title]
      d.data = params[:text]
      if d.save
        "Guardado ok"
      else
        "Error guardando"
      end
    end
  end
  get :doc, :map => "/admin/:id" do
    @doc = Document[params[:id]]
    render "admin/doc"
  end
  post :reparse_doc, :map => "/admin/:id/reparse" do
    @doc = Document[params[:id]]
    params[:people].each{|n|
      p = Person.find_or_create(:name => n)
      @doc.add_person(p)
    }
  end
  get :reparse_doc, :map => "/admin/:id/reparse" do
    @doc = Document[params[:id]]
    @person_names = Hash.new{|hash,key| hash[key]=[]}
    @doc.extract.person_names.each{|nombre| 
      @person_names[ActiveSupport::Inflector.transliterate(nombre.to_s.downcase)] << nombre 
    }
    render "admin/reparse"
  end
  get :persons, :map => "/admin/:id/nombres" do
    @doc = Document[params[:id]]
    @people = @doc.person
    render "admin/people_list"
  end
  get :nombre, :map => "/admin/:doc_id/nombres/:id" do
    @person = Person[params[:id]]
    @what = Milestone.what_list
    @where = Milestone.where_list 
    doc = Document[params[:doc_id]]
    person_name = ActiveSupport::Inflector.transliterate(@person.name).downcase
    @fragments = doc.extract.person_names.find_all{|name| 
      name = ActiveSupport::Inflector.transliterate(name.to_s.downcase)
      name == person_name
    }
    render "admin/person"
  end
  get :context do
    if params[:fragment_id]
      data=params[:fragment_id].match(/frag:doc=([0-9]+):([0-9]+)-([0-9]+)/)
      doc_id=data[1]
      pos_start=data[2]
      pos_end=data[3]
    else
      doc_id=params[:doc_id]
      pos_start=params[:start]
      pos_end=params[:end]
    end
    params[:around] ||= 200
    pos_start   = pos_start.to_i - params[:around].to_i
    pos_start   = 0 if pos_start < 0
    pos_end     = pos_end.to_i + params[:around].to_i

    fragment=Document[doc_id].fragment(pos_start,pos_end)
    r={:fragment_id => fragment.fragment_id, :text => markup_fragment(fragment)}.to_json
    r
  end
  post :classify_name, :map => "/admin/name/classify" do
    r=false
    if params[:name] and params[:training]
      Text::PersonName.train(params[:training],params[:name])
      r=Text::PersonName.training_save
    end
    r.to_json
  end
  get :person, :map => "/admin/person/" do
    puts params
    person = Person.where(:name => params[:name].strip).first || Person.create(:name => params[:name].strip)
    person.values.to_json
  end
  post :person, :map => "/admin/person/" do
    person = Person.where(:name => params[:name].strip).first || Person.create(:name => params[:name].strip)
    Array(params[:person][:milestones]).each{|milestone|
      data = milestone.dup
      data.delete("id")
      data[:what] = ! data["what_txt"].blank? ? data["what_txt"] : data["what_opc"]
      data.delete("what_txt")
      data.delete("what_opc")
      data[:where] = ! data["where_txt"].blank? ? data["where_txt"] : data["where_opc"]
      data.delete("where_txt")
      data.delete("where_opc")
      puts data.inspect
      m=Milestone.new(data)
      person.add_milestone(m) 
    }
    person.save_changes
    params.values.inspect
  end

end
