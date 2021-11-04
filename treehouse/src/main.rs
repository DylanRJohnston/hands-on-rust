use std::{error::Error, io};

fn readline() -> Result<String, io::Error> {
    let mut data = String::new();

    io::stdin().read_line(&mut data)?;

    return Ok(data.trim().to_lowercase());
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("Hello, what's your name?");

    let your_name = readline()?;

    println!("Hello, {}", your_name);

    Ok(())
}
