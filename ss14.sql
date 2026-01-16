create database session14;
use session14;


-- bài 1 : 
create table users (
    user_id int auto_increment primary key,
    username varchar(50) not null,
    posts_count int default 0
);

create table posts (
    post_id int auto_increment primary key,
    user_id int not null,
    content text not null,
    created_at datetime default current_timestamp,
    constraint fk_posts_users
        foreign key (user_id) references users(user_id)
);

insert into users (username) values ('jiren');

start transaction;
insert into posts (user_id, content) values (1, 'Bài viết đầu tiên');
update users set posts_count = posts_count + 1 where user_id = 1;
commit;

start transaction;
insert into posts (user_id, content)
values (999, 'Bài viết lỗi');
update users set posts_count = posts_count + 1 where user_id = 999;
rollback;

-- bai 2 : 
alter table posts
add column likes_count int default 0;

create table likes (
    like_id int auto_increment primary key,
    post_id int not null,
    user_id int not null,
    constraint fk_likes_posts foreign key (post_id) references posts(post_id),
    constraint fk_likes_users foreign key (user_id) references users(user_id),
    constraint unique_like unique (post_id, user_id)
);

start transaction;
insert into likes (post_id, user_id) values (1, 1);
update posts set likes_count = likes_count + 1 where post_id = 1;
commit;

start transaction;
insert into likes (post_id, user_id) values (1, 1); 
update posts set likes_count = likes_count + 1 where post_id = 1;
rollback;

-- bai 3 : 
alter table users
add following_count int default 0,
add followers_count int default 0;

create table followers (
    follower_id int,
    followed_id int,
    primary key (follower_id, followed_id),
    foreign key (follower_id) references users(user_id),
    foreign key (followed_id) references users(user_id)
);

delimiter $$
create procedure sp_follow_user(
    in p_follower_id int,
    in p_followed_id int
)
begin
    start transaction;
    if p_follower_id = p_followed_id
       or not exists (select 1 from users where user_id = p_follower_id)
       or not exists (select 1 from users where user_id = p_followed_id)
       or exists (
            select 1 from followers
            where follower_id = p_follower_id
                and followed_id = p_followed_id
       )
    then
        rollback;
    else
        insert into followers values (p_follower_id, p_followed_id);

        update users
        set following_count = following_count + 1
        where user_id = p_follower_id;

        update users
        set followers_count = followers_count + 1
        where user_id = p_followed_id;

        commit;
    end if;
end$$
delimiter ;

call sp_follow_user(1, 2); 
call sp_follow_user(1, 2); 
call sp_follow_user(1, 1); 

-- bai 4 : 

alter table posts
add comments_count int default 0;

create table comments (
    comment_id int auto_increment primary key,
    post_id int not null,
    user_id int not null,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (post_id) references posts(post_id),
    foreign key (user_id) references users(user_id)
);

delimiter $$
create procedure sp_post_comment(
    in p_post_id int,
    in p_user_id int,
    in p_content text
)
begin
    start transaction;
    insert into comments (post_id, user_id, content)
    values (p_post_id, p_user_id, p_content);

    savepoint after_insert;
    if p_post_id = -1 then
        rollback to after_insert;
    else
        update posts
        set comments_count = comments_count + 1
        where post_id = p_post_id;
        commit;
    end if;
end$$
delimiter ;

call sp_post_comment(1, 1, 'Bình luận hợp lệ');
call sp_post_comment(-1, 1, 'Bình luận lỗi');

-- bai 5 : 

create table delete_log (
    log_id int auto_increment primary key,
    post_id int,
    deleted_by int,
    deleted_at datetime default current_timestamp
);

delimiter $$
create procedure sp_delete_post(
    in p_post_id int,
    in p_user_id int
)
begin
    if not exists (
        select 1 from posts
        where post_id = p_post_id and user_id = p_user_id
    ) then
        rollback;
    else
        start transaction;
        delete from likes where post_id = p_post_id;
        delete from comments where post_id = p_post_id;
        delete from posts where post_id = p_post_id;

        update users
        set posts_count = posts_count - 1
        where user_id = p_user_id;

        insert into delete_log (post_id, deleted_by)
        values (p_post_id, p_user_id);

        commit;
    end if;
end$$
delimiter ;

call sp_delete_post(1, 1);
call sp_delete_post(1, 2);

-- bai 6 : 
create table friend_requests (
    request_id int auto_increment primary key,
    from_user_id int,
    to_user_id int,
    status enum('pending','accepted','rejected') default 'pending'
);

create table friends (
    user_id int,
    friend_id int,
    primary key (user_id, friend_id)
);

alter table users
add friends_count int default 0;

delimiter $$
create procedure sp_accept_friend_request(
    in p_request_id int,
    in p_to_user_id int
)
begin
    declare v_from_user int;

    set transaction isolation level repeatable read;
    start transaction;

    select from_user_id into v_from_user
    from friend_requests
    where request_id = p_request_id
          and to_user_id = p_to_user_id
          and status = 'pending';

    if v_from_user is null
       or exists (
            select 1 from friends
            where user_id = p_to_user_id
                and friend_id = v_from_user
       )
    then
        rollback;
    else
        insert into friends values (p_to_user_id, v_from_user);
        insert into friends values (v_from_user, p_to_user_id);

        update users
        set friends_count = friends_count + 1
        where user_id in (p_to_user_id, v_from_user);

        update friend_requests
        set status = 'accepted'
        where request_id = p_request_id;

        commit;
    end if;
end$$
delimiter ;

call sp_accept_friend_request(1, 2);
call sp_accept_friend_request(1, 2);
