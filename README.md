> [!WARNING]  
> Gleamx is a new language ontop of Gleam that compiles to gleam.
> Gleam build tool, compiler, language server, and any other tooling will not work with gleamx
> and compiler errors will be poor (line and column will not perfectly match .gleamx sourcecode etc.)

# gleamx

```sh
gleam add --dev gleamx
```

**JSX-like preprocessor for gleam.**

just end your files with `.gleamx` and run `gleam run -m gleamx` to compile all `.gleamx` files in `src` folder to plain `gleam` files

start a gleamx block with `<?`, then write normal html intercepted with gleam code in `{}` (variables and function-calls can be used a childs of html elements without `{}`). And you can use spreads to use list of elements

```gleam
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html


pub fn login_page(valid valid: Bool) -> Element(t) {
  form_page(
    "Login", "/login",
    fields: [
      input(name: "email"   , is: "text"    , valid:),
      input(name: "password", is: "password", valid:),
    ],
    buttons: [
      <? <a class="button" href="/signup"> text("Sign Up") </a>,
      submit_button("Login"),
    ]
  )
}

fn form_page(
  title: String,
  action: String,
  fields fields: List(Element(t)),
  buttons buttons: List(Element(t)),
) -> Element(t) {

  page(
    <? <form method="POST" action={action}>
      <div class="fields"> ..fields </div>
      <div class="buttons">
        <span> text("just a test to show spreading") </span>
        ..buttons
      </div>
    </form>
  )
}

fn page(title: String, elements: List(Element(t))) -> Element(t) {
  <? <html>
    <head>
      <title> {title} </title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <link rel="stylesheet" href="/static/app.css">
    </head>
    <body> ..elements </body>
  </html>
}
```

## todo
I want to write a vscode plugin with syntax-highlighting, error messages and all the langserver goodies. I think I can write something ontop of the gleam langserver that uses some kind of generated sourcemap to map between location in gleamx code and generated gleam file. I alredy generate a datastructure for that while generating, but I have to first research how languageservers work
