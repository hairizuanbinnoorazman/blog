+++
title = "Replicating golang interfaces with static python, run with mypy"
description = "Replicating golang interfaces with static python, run with mypy"
tags = [
    "golang",
    "python",
]
date = "2023-06-21"
categories = [
    "golang",
    "python",
]
+++

After coding in both Python and Golang, I now have a very strong preference for strongly typed languages. There is a certain charm and beauty in being able to have the IDE that I'm working in able to provide good autocomplete suggestions for the code - there is less for a need to keep moving files in the codebases just to ensure that the function spelling and params are correct etc. For smaller programs, dynamic types languages are still ok but they get very unwieldy once they go pass the hundreds of lines of code mark.

In a previous post, [Writing static python with mypy](/writing-static-python-with-mypy), I finally started playing around with using static python via the usage of mypy library and the utilities that surround it. That post provided some simple examples that would potentially cover some of the more common use cases.

However, even with all that, there is one thing that I really like in Golang language that I was checking around in static Python - the `interface` (well in Golang's terms). With that in place, that would allow us to substitute in different implementations of code in without tying us down to one specific implementation. As one always say, always expect change - code can be working fine but it could introduce breaking changes the next day or even become deprecated.

Reference for the below Golang code: https://github.com/hairizuanbinnoorazman/slides-to-video

Let's look at some golang code first:

```golang
package user

...

type Store interface {
	Create(ctx context.Context, u User) error
	GetUser(ctx context.Context, ID string) (User, error)
	GetUserByEmail(ctx context.Context, Email string) (User, error)
	GetUserByActivationToken(ctx context.Context, ActivationToken string) (User, error)
	GetUserByForgetPasswordToken(ctx context.Context, ForgetPasswordToken string) (User, error)
	Update(ctx context.Context, ID string, setters ...func(*User) error) (User, error)
}

...
```

Let's say we have some sort of storage component for user entities in an application. As long as our types conform and have the above said functions, it should be for such an implementation to accept to other parts of the codebases. For the above user store, we can use the `Store` interface from the user package. For the reference Golang code, there are 2 types of storage for the User package, one is Datastore backend and other is MySQL backend.

```golang
type Authenticate struct {
	Logger       logger.Logger
	TableName    string
	ClientID     string
	ClientSecret string
	RedirectURI  string
	Auth         services.Auth
	UserStore    user.Store
}
```

What would be a similar-ish implementation for the python codebase?

The "interface" can be replicated by using the Protocol keyword and stuffing it into a class. The `...` denotes an empty function - we shouldn't need to define functions for an "interface".

```python
class UserStore(Protocol):
    def create_user(self, u: User) -> None: ...
    def update_user(self, u: User) -> None: ...
    def delete_user(self, id: str) -> None: ...
    def get_user_by_id(self, id: str) -> User: ...
```

The above would be managing the following the `User` class.

```python
class User():
    id: str
    date_created: str

    def __init__(self) -> None:
        self.id = str(uuid.uuid4())
        self.date_created = datetime.now().strftime("%y-%m-%d")
```

One possible implementation for the above is one where we have class that have all the above functions and manages the state by storing it in "memory" of the python script (in the case of a web-server, the state will be maintained for as long as the application remains running).

```python
class MemoryUserStore():
    memory_store: dict[str, User]

    def __init__(self) -> None:
        self.memory_store = {}

    def create_user(self, u: User) -> None:
        self.memory_store[u.id] = u

    def update_user(self, u: User) -> None:
        self.memory_store[u.id] = u

    def delete_user(self, id: str) -> None:
        self.memory_store.pop(id)

    def get_user_by_id(self, id: str) -> User:
        return self.memory_store[id]
```

Another possible implementation for this would be store the content of the data to be store in some form of Json file?

```python
class JSONUserStore():
    internal: dict[str, str]
    file_name: str

    def _populate_internal(self) -> None:
        f = open(self.file_name, 'r')
        raw = json.load(f)
        for i in raw:
            self.internal[i] = raw[i]
        f.close()

    def _persist(self) -> None:
        f = open(self.file_name, 'w')
        json.dump(self.internal, f)
        f.close()

    def __init__(self, file_name: str) -> None:
        self.internal = {}
        self.file_name = file_name

    def create_user(self, u: User) -> None:
        self._populate_internal()
        self.internal[u.id] = json.dumps(u.__dict__)
        self._persist()
        self.internal = {}

    def update_user(self, u: User) -> None:
        self._populate_internal()
        self.internal[u.id] = json.dumps(u.__dict__)
        self._persist()
        self.internal = {}

    def delete_user(self, id: str) -> None:
        self._populate_internal()
        self.internal.pop(id)
        self._persist()
        self.internal = {}

    def get_user_by_id(self, id: str) -> User:
        self._populate_internal()
        item = self.internal[id]
        self._persist()
        self.internal = {}
        processed_item = json.loads(item)
        fake_user = User()
        fake_user.id = processed_item["id"]
        fake_user.date_created = processed_item["date_created"]
        return fake_user
```

We can have the following driver code to test out the above implementations:

```python
def zzz(us: UserStore) -> None:
    new_user_1 = User()
    print(new_user_1.id)
    new_user_2 = User()
    print(new_user_2.id)
    us.create_user(new_user_1)
    us.create_user(new_user_2)
    gotten_new_user = us.get_user_by_id(new_user_1.id)
    print("new_user_1 {}".format(new_user_1.id))
    print("gotten_new_user {}".format(gotten_new_user.id))
    assert gotten_new_user.id == new_user_1.id, "id is not the same"
    return


mus = MemoryUserStore()
jus = JSONUserStore("zz.json")
zzz(jus)
```

Do note that for the bottom section, it's extremely trivial to switch over the implementations - let's say for that we want to rely on memory store when we're on server due to overabundance of memory but rely on json user store where it stores state in files in smaller systems such as workstations:

```python
mus = MemoryUserStore()
jus = JSONUserStore("zz.json")
zzz(mus)
```

However, as much as these static typing mechanisms/tooling is in python now, it's still a pain to setup and is something that I feel require a larger codebase to test it on to see how it is affected by such tooling. Technically, with static typing tools in place, it should make the developer experience on the codebase way better and simpler. However, at the moment, I haven't gotten the time to try it out - so maybe that could be done in a future blog post.

## References:
- https://andrewbrookins.com/technology/building-implicit-interfaces-in-python-with-protocol-classes/
- https://peps.python.org/pep-0544/