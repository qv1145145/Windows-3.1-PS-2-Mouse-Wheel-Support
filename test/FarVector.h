#ifndef FARVECTOR_H
#define FARVECTOR_H

#include <windows.h>
#include <stddef.h>

#ifndef GlobalAllocPtr
#define GlobalAllocPtr(flags, cb) (GlobalLock(GlobalAlloc((flags), (cb))))
#endif
#ifndef GlobalFreePtr
#define GlobalFreePtr(lp) (GlobalUnlock((HGLOBAL)lp), GlobalFree(GlobalHandle((HGLOBAL)lp)))
#endif

// FarVector: 存储T*的动态数组，使用GlobalAllocPtr管理内存
template <class T>
class FarVector {
private:
    T** m_data;               // Large模型下默认far，无需__far修饰
    unsigned m_capacity;
    unsigned m_size;
    unsigned m_growFactor;

public:
    FarVector(unsigned initCap = 16, unsigned grow = 2)
        : m_data(NULL), m_capacity(0), m_size(0), m_growFactor(grow) {
        if (initCap > 0) resize(initCap);
    }

    FarVector(const FarVector& other)
        : m_data(NULL), m_capacity(0), m_size(0), m_growFactor(other.m_growFactor) {
        resize(other.m_capacity);
        m_size = other.m_size;
        for (unsigned i = 0; i < m_size; i++)
            m_data[i] = other.m_data[i];
    }

    ~FarVector() {
        clear();
        if (m_data) GlobalFreePtr(m_data);
    }

    FarVector& operator=(const FarVector& other) {
        if (this != &other) {
            clear();
            if (m_capacity < other.m_capacity) resize(other.m_capacity);
            m_size = other.m_size;
            for (unsigned i = 0; i < m_size; i++) m_data[i] = other.m_data[i];
            m_growFactor = other.m_growFactor;
        }
        return *this;
    }

    unsigned entries() const { return m_size; }
    int isEmpty() const { return m_size == 0; }

    T*& operator[](unsigned idx) { return m_data[idx]; }
    T* const& operator[](unsigned idx) const { return m_data[idx]; }

    T*& at(unsigned idx) {
        if (idx >= m_size) return *(T**)NULL;
        return m_data[idx];
    }

    int append(T* elem) {
        if (m_size >= m_capacity) {
            unsigned newCap = m_capacity * m_growFactor;
            if (newCap == 0) newCap = 16;
            if (!resize(newCap)) return 0;
        }
        m_data[m_size++] = elem;
        return 1;
    }

    int insertAt(unsigned idx, T* elem) {
        if (idx > m_size) return 0;
        if (m_size >= m_capacity) {
            unsigned newCap = m_capacity * m_growFactor;
            if (newCap == 0) newCap = 16;
            if (!resize(newCap)) return 0;
        }
        for (unsigned i = m_size; i > idx; i--)
            m_data[i] = m_data[i-1];
        m_data[idx] = elem;
        m_size++;
        return 1;
    }

    T* removeAt(unsigned idx) {
        if (idx >= m_size) return NULL;
        T* elem = m_data[idx];
        for (unsigned i = idx; i < m_size-1; i++)
            m_data[i] = m_data[i+1];
        m_size--;
        return elem;
    }

    void clear() { m_size = 0; }

    int indexOf(const T* elem) const {
        for (unsigned i = 0; i < m_size; i++)
            if (m_data[i] == elem) return i;
        return -1;
    }

    int find(const T& value) const {
        for (unsigned i = 0; i < m_size; i++)
            if (*m_data[i] == value) return i;
        return -1;
    }

    unsigned removeAll(const T& value) {
        unsigned removed = 0;
        for (int i = m_size-1; i >= 0; i--) {
            if (*m_data[i] == value) {
                removeAt(i);
                removed++;
            }
        }
        return removed;
    }

    int resize(unsigned newCap) {
        if (newCap == 0) newCap = 1;
        T** newData = (T**)GlobalAllocPtr(GMEM_MOVEABLE, newCap * sizeof(T*));
        if (!newData) return 0;
        if (m_data) {
            for (unsigned i = 0; i < m_size; i++)
                newData[i] = m_data[i];
            GlobalFreePtr(m_data);
        }
        m_data = newData;
        m_capacity = newCap;
        return 1;
    }

    unsigned capacity() const { return m_capacity; }
    void setGrowFactor(unsigned g) { if (g >= 2) m_growFactor = g; }
};

#endif