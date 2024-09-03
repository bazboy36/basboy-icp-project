import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import List "mo:base/List";
import Option "mo:base/Option";

actor {
  type BookId = Nat;
  type MemberId = Nat;
  type BorrowId = Nat;

  type Book = {
    id : BookId;
    title : Text;
    author : Text;
    isbn : Text;
    totalCopies : Nat;
    availableCopies : Nat;
  };

  type Member = {
    id : MemberId;
    name : Text;
    email : Text;
    joinDate : Time.Time;
  };

  type BorrowRecord = {
    id : BorrowId;
    bookId : BookId;
    memberId : MemberId;
    borrowDate : Time.Time;
    dueDate : Time.Time;
    returnDate : ?Time.Time;
  };

  var books = Buffer.Buffer<Book>(0);
  var members = Buffer.Buffer<Member>(0);
  var borrowRecords = Buffer.Buffer<BorrowRecord>(0);

  public func addBook(title : Text, author : Text, isbn : Text, copies : Nat) : async BookId {
    let bookId = books.size();
    let newBook : Book = {
      id = bookId;
      title = title;
      author = author;
      isbn = isbn;
      totalCopies = copies;
      availableCopies = copies;
    };
    books.add(newBook);
    bookId;
  };

  public query func getBook(bookId : BookId) : async ?Book {
    if (bookId < books.size()) {
      ?books.get(bookId);
    } else {
      null;
    };
  };

  public func updateBookCopies(bookId : BookId, newTotalCopies : Nat) : async Bool {
    if (bookId < books.size()) {
      var book = books.get(bookId);
      let newAvailableCopies = if (newTotalCopies > book.totalCopies) {
        book.availableCopies + (newTotalCopies - book.totalCopies);
      } else {
        Nat.sub(book.availableCopies, Nat.min(book.totalCopies - newTotalCopies, book.availableCopies));
      };
      book := {
        id = book.id;
        title = book.title;
        author = book.author;
        isbn = book.isbn;
        totalCopies = newTotalCopies;
        availableCopies = newAvailableCopies;
      };
      books.put(bookId, book);
      true;
    } else {
      false;
    };
  };

  public func addMember(name : Text, email : Text) : async MemberId {
    let memberId = members.size();
    let newMember : Member = {
      id = memberId;
      name = name;
      email = email;
      joinDate = Time.now();
    };
    members.add(newMember);
    memberId;
  };

  public query func getMember(memberId : MemberId) : async ?Member {
    if (memberId < members.size()) {
      ?members.get(memberId);
    } else {
      null;
    };
  };

  public func borrowBook(bookId : BookId, memberId : MemberId) : async ?BorrowId {
    switch (await getBook(bookId), await getMember(memberId)) {
      case (?book, ?member) {
        if (book.availableCopies > 0) {
          let borrowId = borrowRecords.size();
          let borrowDate = Time.now();
          let dueDate = borrowDate + 14 * 24 * 60 * 60 * 1_000_000_000; 
          let newBorrowRecord : BorrowRecord = {
            id = borrowId;
            bookId = bookId;
            memberId = memberId;
            borrowDate = borrowDate;
            dueDate = dueDate;
            returnDate = null;
          };
          borrowRecords.add(newBorrowRecord);
          
          let updatedBook : Book = {
            id = book.id;
            title = book.title;
            author = book.author;
            isbn = book.isbn;
            totalCopies = book.totalCopies;
            availableCopies = book.availableCopies - 1;
          };
          books.put(bookId, updatedBook);
          
          ?borrowId;
        } else {
          null; // Book not available
        };
      };
      case _ {
        null; // Invalid book or member ID
      };
    };
  };

  public func returnBook(borrowId : BorrowId) : async Bool {
    if (borrowId < borrowRecords.size()) {
      var record = borrowRecords.get(borrowId);
      if (Option.isNull(record.returnDate)) {
        record := {
          id = record.id;
          bookId = record.bookId;
          memberId = record.memberId;
          borrowDate = record.borrowDate;
          dueDate = record.dueDate;
          returnDate = ?Time.now();
        };
        borrowRecords.put(borrowId, record);

        let book = books.get(record.bookId);
        let updatedBook : Book = {
          id = book.id;
          title = book.title;
          author = book.author;
          isbn = book.isbn;
          totalCopies = book.totalCopies;
          availableCopies = book.availableCopies + 1;
        };
        books.put(record.bookId, updatedBook);

        true;
      } else {
        false; // Book already returned
      };
    } else {
      false; // Invalid borrow ID
    };
  };

  public query func getBooksBorrowedByMember(memberId : MemberId) : async [BookId] {
    let memberBorrows = Buffer.Buffer<BookId>(0);
    for (record in borrowRecords.vals()) {
      if (record.memberId == memberId and Option.isNull(record.returnDate)) {
        memberBorrows.add(record.bookId);
      };
    };
    Buffer.toArray(memberBorrows);
  };

  public query func getOverdueBooks() : async [(BookId, MemberId, Time.Time)] {
    let overdueRecords = Buffer.Buffer<(BookId, MemberId, Time.Time)>(0);
    let currentTime = Time.now();
    for (record in borrowRecords.vals()) {
      if (Option.isNull(record.returnDate) and record.dueDate < currentTime) {
        overdueRecords.add((record.bookId, record.memberId, record.dueDate));
      };
    };
    Buffer.toArray(overdueRecords);
  };

  public query func getLibraryStatistics() : async {
    totalBooks : Nat;
    totalMembers : Nat;
    booksInCirculation : Nat;
    overdueBooksCount : Nat;
  } {
    var booksInCirculation = 0;
    var overdueBooksCount = 0;
    let currentTime = Time.now();

    for (record in borrowRecords.vals()) {
      if (Option.isNull(record.returnDate)) {
        booksInCirculation += 1;
        if (record.dueDate < currentTime) {
          overdueBooksCount += 1;
        };
      };
    };

    {
      totalBooks = books.size();
      totalMembers = members.size();
      booksInCirculation = booksInCirculation;
      overdueBooksCount = overdueBooksCount;
    };
  };
};